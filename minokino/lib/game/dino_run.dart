import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:hive/hive.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';

import '/game/dino.dart';
import '/widgets/hud.dart';
import '/models/dino_character_ids.dart';
import '/models/settings.dart';
import '/game/audio_manager.dart';
import '/game/enemy_manager.dart';
import '/models/player_data.dart';
import '/widgets/pause_menu.dart';
import '/widgets/game_over_menu.dart';
import '/widgets/continue_ad_menu.dart';

// This is the main flame game class.
class DinoRun extends FlameGame with TapDetector, HasCollisionDetection {
  DinoRun({super.camera});

  // List of all the image assets.
  static final List<String> _imageAssets = <String>[
    ...DinoCharacterIds.all.map((id) => DinoCharacterIds.assetFileName(id)),
    'Bat/Flying (46x30).png',
    'Enemy/Enemy3No-Move-Idle.png',
    'Enemy/Enemy3No-Move-Die.png',
    'Mushroom/Mushroom-Run.png',
    'Mushroom/Mushroom-Die.png',
    'Daemon/flying.png',
    'Daemon/die.png',
    'Plant1/Plant1_Attack_with_shadow.png',
    'Plant1/Plant1_Death_with_shadow.png',
    'Plant2/Plant2_Attack_with_shadow.png',
    'Plant2/Plant2_Death_with_shadow.png',
    'Plant3/Plant3_Attack_with_shadow.png',
    'Plant3/Plant3_Death_with_shadow.png',
    'parallax2/prl1.png',
    'parallax2/prl2.png',
    'parallax2/prl3.png',
    'parallax2/prl4.png',
    'parallax2/prl5.png',
    'parallax2/prl6.png',
  ];

  // List of all the audio assets.
  static const _audioAssets = [
    '8BitPlatformerLoop.wav',
    'hurt7.wav',
    'jump14.wav',
  ];

  late Dino _dino;
  late Settings settings;
  late PlayerData playerData;
  late EnemyManager _enemyManager;

  late ParallaxComponent _parallaxBackground;

  Vector2 get virtualSize => camera.viewport.virtualSize;

  /// Run scroll speed grows continuously with score.
  static const double _parallaxBaseX = 8.5;
  static const double _speedPerScore = 0.012;
  static const double _maxSpeedMultiplier = 3.5;

  /// Global scale for parallax, enemy scroll, spawn cadence, and run-cycle sync.
  static const double _gamePace = 0.95;

  /// Small extra on Minoki only (same [runSpeedMultiplier] base = no desync).
  static const double _characterMovementBoost = 1.12;

  /// Seconds of active run (HUD visible); pauses when pause menu / no HUD.
  double _playtimeSeconds = 0;

  /// Up to 3 rewarded ad continues per run; then final game over only.
  static const int maxAdRevives = 3;
  int adRevivesUsed = 0;
  bool _adSessionRewardHandled = false;

  bool get canOfferAdContinue => adRevivesUsed < maxAdRevives;
  int get adRevivesRemaining => maxAdRevives - adRevivesUsed;
  bool get adSessionRewardHandled => _adSessionRewardHandled;

  /// Ease-in: at t=0 speed is normal; reaches near-full [target] sooner for snappier gameplay.
  static const double _runWarmupSeconds = 4.0;

  /// Even with score 0, run slowly picks up over time (multiplier on top of score core).
  static const double _runTimeBonusMax = 0.28;
  static const double _runTimeBonusTau = 25.0;

  double _runSpeedCoreFromScore() {
    final m = 1.0 + playerData.currentScore * _speedPerScore;
    return m < _maxSpeedMultiplier ? m : _maxSpeedMultiplier;
  }

  /// Target intensity from score + playtime (before start-of-run ease-in).
  double _targetRunCore() {
    final fromScore = _runSpeedCoreFromScore();
    final timeK =
        1.0 + _runTimeBonusMax * (1.0 - math.exp(-_playtimeSeconds / _runTimeBonusTau));
    return (fromScore * timeK).clamp(1.0, _maxSpeedMultiplier);
  }

  /// 0 → 1 how much of [target] we apply (smooth start for whole game).
  double _runWarmupBlend() {
    return 1.0 - math.exp(-_playtimeSeconds / _runWarmupSeconds);
  }

  double get runSpeedMultiplier {
    final double core;
    if (!overlays.isActive(Hud.id)) {
      core = 1.0;
    } else {
      final target = _targetRunCore();
      final w = _runWarmupBlend();
      core = 1.0 + (target - 1.0) * w;
    }
    return core * _gamePace;
  }

  /// Same base as world; tiny boost so legs/jump match scroll visually.
  double get characterMovementMultiplier =>
      runSpeedMultiplier * _characterMovementBoost;

  // This method get called while flame is preparing this game.
  @override
  Future<void> onLoad() async {
    // Makes the game full screen and landscape only.
    await Flame.device.fullScreen();
    await Flame.device.setLandscape();

    /// Read [PlayerData] and [Settings] from hive.
    playerData = await _readPlayerData();
    settings = await _readSettings();

    /// Initilize [AudioManager].
    await AudioManager.instance.init(_audioAssets, settings);

    // Start playing background music. Internally takes care
    // of checking user settings.
    AudioManager.instance.startBgm('8BitPlatformerLoop.wav');

    // Cache all the images.
    await images.loadAll(_imageAssets);

    // This makes the camera look at the center of the viewport.
    camera.viewfinder.position = camera.viewport.virtualSize * 0.5;

    /// Create a [ParallaxComponent] and add it to game.
    _parallaxBackground = await loadParallaxComponent(
      [
        ParallaxImageData('parallax2/prl1.png'),
        ParallaxImageData('parallax2/prl2.png'),
        ParallaxImageData('parallax2/prl3.png'),
        ParallaxImageData('parallax2/prl4.png'),
        ParallaxImageData('parallax2/prl5.png'),
        ParallaxImageData('parallax2/prl6.png'),
      ],
      baseVelocity: Vector2(_parallaxBaseX, 0),
      velocityMultiplierDelta: Vector2(1.5, 0),
    );

    // Add the parallax as the backdrop.
    camera.backdrop.add(_parallaxBackground);
  }

  /// This method add the already created [Dino]
  /// and [EnemyManager] to this game.
  void startGamePlay() {
    _playtimeSeconds = 0;
    final skin = DinoCharacterIds.assetFileName(settings.selectedDino);
    _dino = Dino(images.fromCache(skin), playerData);
    _enemyManager = EnemyManager();

    world.add(_dino);
    world.add(_enemyManager);
  }

  // This method remove all the actors from the game.
  void _disconnectActors() {
    _dino.removeFromParent();
    _enemyManager.removeAllEnemies();
    _enemyManager.removeFromParent();
  }

  // This method reset the whole game world to initial state. 
  void reset() {
    // First disconnect all actions from game world.
    _disconnectActors();

    _playtimeSeconds = 0;

    // Reset player data to inital values.
    playerData.currentScore = 0;
    playerData.lives = PlayerData.maxLives;
    adRevivesUsed = 0;
    _adSessionRewardHandled = false;
  }

  void _openContinueAdMenu() {
    playerData.persistProgress();
    _adSessionRewardHandled = false;
    overlays.remove(Hud.id);
    overlays.add(ContinueAdMenu.id);
    pauseEngine();
    AudioManager.instance.pauseBgm();
  }

  void onAdContinueReward() {
    if (_adSessionRewardHandled) {
      return;
    }
    _adSessionRewardHandled = true;
    continueAfterAd();
  }

  void onAdContinueCancelled() {
    if (_adSessionRewardHandled) {
      return;
    }
    showFinalGameOver();
  }

  void continueAfterAd() {
    adRevivesUsed++;
    playerData.lives = 1;
    _enemyManager.removeAllEnemies();
    if (_dino.isMounted) {
      _dino.revive();
    }
    overlays.remove(ContinueAdMenu.id);
    overlays.add(Hud.id);
    resumeEngine();
    AudioManager.instance.resumeBgm();
  }

  void showFinalGameOver() {
    if (overlays.isActive(GameOverMenu.id)) {
      return;
    }
    if (playerData.lives > 0) {
      return;
    }
    playerData.persistProgress();
    overlays.remove(ContinueAdMenu.id);
    overlays.remove(Hud.id);
    overlays.add(GameOverMenu.id);
    pauseEngine();
    AudioManager.instance.pauseBgm();
  }

  // This method gets called for each tick/frame of the game.
  @override
  void update(double dt) {
    if (playerData.lives <= 0) {
      if (canOfferAdContinue &&
          !overlays.isActive(ContinueAdMenu.id) &&
          !overlays.isActive(GameOverMenu.id)) {
        _openContinueAdMenu();
      } else if (!canOfferAdContinue &&
          playerData.lives <= 0 &&
          !overlays.isActive(GameOverMenu.id) &&
          !overlays.isActive(ContinueAdMenu.id)) {
        showFinalGameOver();
      }
    } else if (overlays.isActive(Hud.id)) {
      _playtimeSeconds += dt;
      final m = runSpeedMultiplier;
      _parallaxBackground.parallax?.baseVelocity.setValues(_parallaxBaseX * m, 0);
    } else {
      _parallaxBackground.parallax?.baseVelocity.setValues(0, 0);
    }
    super.update(dt);
  }

  // This will get called for each tap on the screen.
  @override
  void onTapDown(TapDownInfo info) {
    // Make dino jump only when game is playing.
    // When game is in playing state, only Hud will be the active overlay.
    if (overlays.isActive(Hud.id)) {
      _dino.jump();
    }
    super.onTapDown(info);
  }

  /// This method reads [PlayerData] from the hive box.
  Future<PlayerData> _readPlayerData() async {
    final playerDataBox = await Hive.openBox<PlayerData>(
      'DinoRun.PlayerDataBox',
    );
    final playerData = playerDataBox.get('DinoRun.PlayerData');

    // If data is null, this is probably a fresh launch of the game.
    if (playerData == null) {
      // In such cases store default values in hive.
      await playerDataBox.put('DinoRun.PlayerData', PlayerData());
    }

    // Now it is safe to return the stored value.
    return playerDataBox.get('DinoRun.PlayerData')!;
  }

  /// This method reads [Settings] from the hive box.
  Future<Settings> _readSettings() async {
    final settingsBox = await Hive.openBox<Settings>('DinoRun.SettingsBox');
    final settings = settingsBox.get('DinoRun.Settings');

    // If data is null, this is probably a fresh launch of the game.
    if (settings == null) {
      // In such cases store default values in hive.
      await settingsBox.put('DinoRun.Settings', Settings(bgm: true, sfx: true));
    }

    // Now it is safe to return the stored value.
    return settingsBox.get('DinoRun.Settings')!;
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // On resume, if active overlay is not PauseMenu,
        // resume the engine (lets the parallax effect play).
        if (!(overlays.isActive(PauseMenu.id)) &&
            !(overlays.isActive(GameOverMenu.id)) &&
            !(overlays.isActive(ContinueAdMenu.id))) {
          resumeEngine();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // If game is active, then remove Hud and add PauseMenu
        // before pausing the game.
        if (overlays.isActive(Hud.id)) {
          overlays.remove(Hud.id);
          overlays.add(PauseMenu.id);
        }
        pauseEngine();
        break;
    }
    super.lifecycleStateChange(state);
  }
}
