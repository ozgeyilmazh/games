import 'dart:math';

import 'package:flame/components.dart';

import '/game/enemy.dart';
import '/game/dino_run.dart';
import '/game/plant_enemy.dart';
import '/models/enemy_data.dart';

// This class is responsible for spawning random enemies at certain
// interval of time depending upon players current score.
class EnemyManager extends Component with HasGameReference<DinoRun> {
  // A list to hold data for all the enemies.
  final List<EnemyData> _data = [];

  // Random generator required for randomly selecting enemy type.
  final Random _random = Random();

  static const double _spawnIntervalBase = 2.0;
  static const double _spawnXPaddingMin = 20;
  static const double _spawnXPaddingMax = 150;
  static const double _minGapFromDinoMin = 110;
  static const double _minGapFromDinoMax = 260;

  /// Seconds until the next spawn; shrinks as [DinoRun.runSpeedMultiplier] rises.
  double _spawnCooldown = _spawnIntervalBase;

  double _dinoX() => 32;

  double _rightmostThreatX() {
    var maxX = _dinoX();
    for (final enemy in game.world.children.whereType<Enemy>()) {
      if (enemy.position.x > maxX) {
        maxX = enemy.position.x;
      }
    }
    for (final plant in game.world.children.whereType<PlantEnemy>()) {
      if (plant.position.x > maxX) {
        maxX = plant.position.x;
      }
    }
    return maxX;
  }

  double _nextSpawnX() {
    final m = game.runSpeedMultiplier;
    final speedT = ((m - 1.0) / 2.5).clamp(0.0, 1.0);
    final gapMin = _minGapFromDinoMin + (1.0 - speedT) * 40;
    final gapMax = _minGapFromDinoMax - speedT * 80;
    final dinoX = _dinoX();
    final randomGap = gapMin + _random.nextDouble() * (gapMax - gapMin);
    final aheadOfDino = dinoX + randomGap;
    final aheadOfLastThreat = _rightmostThreatX() + 90 + _random.nextDouble() * 110;
    final offScreen =
        game.virtualSize.x +
        _spawnXPaddingMin +
        _random.nextDouble() * (_spawnXPaddingMax - _spawnXPaddingMin);
    return [aheadOfDino, aheadOfLastThreat, offScreen].reduce(max);
  }

  void _scheduleNextSpawn() {
    final m = game.runSpeedMultiplier;
    final intervalJitter = 0.55 + _random.nextDouble() * 0.95;
    final speedFactor = pow(m, 1.45);
    _spawnCooldown =
        (_spawnIntervalBase / speedFactor * intervalJitter).clamp(0.22, 2.6);
  }

  // This method is responsible for spawning a random enemy.
  void spawnRandomEnemy() {
    if (_random.nextInt(_data.length + 1) == _data.length) {
      _spawnPlant();
      return;
    }

    /// Generate a random index within [_data] and get an [EnemyData].
    final randomIndex = _random.nextInt(_data.length);
    final enemyData = _data.elementAt(randomIndex);
    final enemy = Enemy(enemyData);

    // Help in setting all enemies on ground.
    enemy.anchor = Anchor.bottomLeft;
    enemy.position = Vector2(_nextSpawnX(), game.virtualSize.y - 24);

    // If this enemy can fly, set its y position randomly.
    if (enemyData.canFly) {
      final newHeight = _random.nextDouble() *
          enemyData.flyHeightRandomMultiplier *
          enemyData.textureSize.y;
      enemy.position.y -= newHeight;
    }

    // Due to the size of our viewport, we can
    // use textureSize as size for the components.
    enemy.size = enemyData.textureSize;
    game.world.add(enemy);
  }

  void _spawnPlant() {
    final variant = _random.nextInt(3);
    late final String attackAsset;
    late final String deathAsset;
    late final Vector2 attackTextureSize;
    late final Vector2 deathTextureSize;
    late final double shadowCropLocalY;

    switch (variant) {
      case 0:
        attackAsset = 'Plant1/Plant1_Attack_with_shadow.png';
        deathAsset = 'Plant1/Plant1_Death_with_shadow.png';
        attackTextureSize = Vector2(64, 52);
        deathTextureSize = Vector2(64, 53);
        shadowCropLocalY = 13;
        break;
      case 1:
        attackAsset = 'Plant2/Plant2_Attack_with_shadow.png';
        deathAsset = 'Plant2/Plant2_Death_with_shadow.png';
        attackTextureSize = Vector2(64, 44);
        deathTextureSize = Vector2(64, 48);
        shadowCropLocalY = 11;
        break;
      default:
        attackAsset = 'Plant3/Plant3_Attack_with_shadow.png';
        deathAsset = 'Plant3/Plant3_Death_with_shadow.png';
        attackTextureSize = Vector2(64, 48);
        deathTextureSize = Vector2(64, 45);
        shadowCropLocalY = 12;
        break;
    }

    final plant = PlantEnemy(
      attackImage: game.images.fromCache(attackAsset),
      deathImage: game.images.fromCache(deathAsset),
      attackTextureSize: attackTextureSize,
      deathTextureSize: deathTextureSize,
      shadowCropLocalY: shadowCropLocalY,
    );
    plant.anchor = Anchor.bottomLeft;
    plant.position = Vector2(_nextSpawnX(), game.virtualSize.y - 22);
    game.world.add(plant);
  }

  @override
  void onMount() {
    if (isMounted) {
      removeFromParent();
    }

    // Don't fill list again and again on every mount.
    if (_data.isEmpty) {
      // As soon as this component is mounted, initilize all the data.
      _data.addAll([
        EnemyData(
          image: game.images.fromCache('Bat/Flying (46x30).png'),
          nFrames: 7,
          stepTime: 0.1,
          textureSize: Vector2(46, 30),
          speedX: 135,
          canFly: true,
        ),
        EnemyData(
          image: game.images.fromCache('Daemon/flying.png'),
          nFrames: 4,
          stepTime: 0.12,
          textureSize: Vector2(81, 71),
          speedX: 135,
          canFly: true,
          stompable: true,
          dieImage: game.images.fromCache('Daemon/die.png'),
          dieNFrames: 7,
          dieStepTime: 0.07,
          dieTextureSize: Vector2(81, 71),
          flyHeightRandomMultiplier: 0.65,
          visualScale: 0.82,
        ),
        EnemyData(
          image: game.images.fromCache('Enemy/Enemy3No-Move-Idle.png'),
          nFrames: 8,
          stepTime: 0.12,
          textureSize: Vector2(64, 64),
          speedX: 125,
          canFly: false,
          stompable: true,
          dieImage: game.images.fromCache('Enemy/Enemy3No-Move-Die.png'),
          dieNFrames: 15,
          dieStepTime: 0.06,
        ),
        EnemyData(
          image: game.images.fromCache('Mushroom/Mushroom-Run.png'),
          nFrames: 8,
          stepTime: 0.1,
          // Run sheet is 640x36 → 8 frames of 80x36.
          textureSize: Vector2(80, 36),
          speedX: 125,
          canFly: false,
          stompable: true,
          dieImage: game.images.fromCache('Mushroom/Mushroom-Die.png'),
          // Die sheet is 880x38 → 11 frames of 80x38.
          dieNFrames: 11,
          dieStepTime: 0.07,
          dieTextureSize: Vector2(80, 38),
        ),
      ]);
    }
    _spawnCooldown = _spawnIntervalBase;
    _scheduleNextSpawn();
    super.onMount();
  }

  @override
  void update(double dt) {
    _spawnCooldown -= dt;
    if (_spawnCooldown <= 0) {
      spawnRandomEnemy();
      _scheduleNextSpawn();
    }
    super.update(dt);
  }

  void removeAllEnemies() {
    final enemies = game.world.children.whereType<Enemy>();
    for (var enemy in enemies) {
      enemy.removeFromParent();
    }
    for (final plant in game.world.children.whereType<PlantEnemy>()) {
      plant.removeFromParent();
    }
  }
}
