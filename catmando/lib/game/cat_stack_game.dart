import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import 'cat_sprites.dart';
import 'ad_manager.dart';
import 'background/sky_background.dart';
import 'background/background_theme.dart';
import 'components/ground_body.dart';
import 'components/stacked_cat_body.dart';
import 'components/swinging_cat.dart';
import 'game_audio.dart';
import 'game_config.dart';
import 'game_state.dart';
import 'score_storage.dart';

class CatStackGame extends Forge2DGame with TapCallbacks {
  CatStackGame()
      : super(
          gravity: GameConfig.gravity,
          zoom: GameConfig.zoom,
        );

  static const String startMenuOverlay = 'StartMenu';
  static const String hudOverlay = 'Hud';
  static const String continueAdOverlay = 'ContinueAdMenu';
  static const String gameOverOverlay = 'GameOver';

  static const int maxAdRevives = 3;

  /// Game over inişinde üst şehir katmanları kaybolur (sesle birlikte başlar).
  double get cityDescentFade => _gameOverDescentActive
      ? (1 - _gameOverPanT).clamp(0.0, 1.0)
      : 1.0;

  CatStackPhase phase = CatStackPhase.ready;
  int score = 0;
  int highScore = 0;
  int adRevivesUsed = 0;
  bool _adSessionRewardHandled = false;

  bool get canOfferAdContinue => adRevivesUsed < maxAdRevives;
  int get adRevivesRemaining => maxAdRevives - adRevivesUsed;
  bool get adSessionRewardHandled => _adSessionRewardHandled;

  final math.Random _random = math.Random();
  int? _lastSpriteIndex;

  VoidCallback? onStateChanged;

  SwingingCat? swingingCat;
  final List<StackedCatBody> stackedCats = [];

  double stackTopY = 0;
  double _fallTimer = 0;
  double _stabilizeTimer = 0;
  int _landCounter = 0;
  int _stackStableCounter = 0;
  double _collapseTimer = 0;
  double _postContinueGraceTimer = 0;
  bool _gameOverSoundPlayed = false;
  bool _gameOverDescentActive = false;
  bool _awaitingGameOverUi = false;
  bool _offerContinueOnUi = false;

  double _gameOverPanT = 1;
  double _gameOverPanStartY = 0;
  double _gameOverPanTargetY = 0;
  double _gameOverPanStartX = 0;
  double _lockedCameraX = 0;

  late final SkyBackground _skyBackground;

  int _collapseCheckFrame = 0;
  bool _stackReleasedForCollapse = false;
  final Map<StackedCatBody, StackedCatBody?> _supportBelowCache = {};

  bool get _isPlaying =>
      phase != CatStackPhase.gameOver && phase != CatStackPhase.ready;

  StackedCatBody? get _activeFall =>
      stackedCats.isEmpty ? null : stackedCats.last;

  double get _platformTopY =>
      GameConfig.groundY - GameConfig.groundHalfH;

  double get _visibleHalfWidth => camera.visibleWorldRect.width / 2;

  /// Nişan: kule tepesini takip et; aşırı lean'de tabana doğru yumuşat.
  /// (Yamuk ama ayakta kuleyi game over yapmaz — sadece ip/kamerayı sınırlar.)
  double get _aimX {
    final top = _topSettledCat;
    final base = _baseSettledCat;
    if (top == null) return 0;
    if (base == null || identical(top, base)) return top.body.position.x;

    final maxLean = base.catInfo.contentWorldSize.x *
        GameConfig.maxStackLeanFromBaseFactor;
    final raw = top.body.position.x - base.body.position.x;
    final clamped = raw.clamp(-maxLean, maxLean);
    return base.body.position.x + clamped;
  }

  double _computeCameraTargetX() => _aimX;

  double swingHorizontalFor(CatSpriteInfo cat) {
    final room = _visibleHalfWidth - cat.contentHalfW - 0.15;
    return math.min(GameConfig.swingHorizontal, room);
  }

  Vector2 get ropeAnchor {
    final top = camera.visibleWorldRect.top;
    return Vector2(_aimX, top + GameConfig.ropeTopInset);
  }

  double get ropeLengthWorld {
    final h = camera.viewport.size.y;
    return h * GameConfig.ropeScreenHeightRatio / camera.viewfinder.zoom;
  }

  @override
  Color backgroundColor() =>
      BackgroundTheme.paletteForScore(score).skyTop;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    images.prefix = 'assets/cats/';
    await CatSprites.load();
    await GameAudio.init();

    highScore = ScoreStorage.loadHighScore();

    _skyBackground = SkyBackground();
    camera.backdrop.add(_skyBackground);

    world.add(GroundBody(centerX: 0));
    overlays.add(startMenuOverlay);
    _spawnReadyPreview();
    _updateCamera(instant: true);
    GameAudio.playMenuMusic();
  }

  /// Menüde ip sallanır — oyun henüz başlamadı (Flappy Bird hazır ekranı).
  void _spawnReadyPreview() {
    _dismissSwingingCat();
    final spriteIndex = _pickSpriteIndex();
    swingingCat = SwingingCat(spriteIndex: spriteIndex, score: score);
    world.add(swingingCat!);
  }

  void startGame() {
    if (phase != CatStackPhase.ready) return;
    overlays.remove(startMenuOverlay);
    overlays.add(hudOverlay);
    phase = CatStackPhase.swinging;
    GameAudio.playGameplayMusic();

    final preview = swingingCat;
    if (preview == null) {
      _spawnSwingingCat();
    } else {
      if (stackedCats.isEmpty && score == 0) {
        _setStackTopOnGround(preview.spriteIndex);
      }
      _lockSettledStack();
    }
    onStateChanged?.call();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!_isPlaying || phase != CatStackPhase.swinging || swingingCat == null) {
      return;
    }
    swingingCat!.release();
  }

  void onCatReleased({
    required Vector2 position,
    required double angle,
    required Vector2 linearVelocity,
    required int spriteIndex,
  }) {
    if (!_isPlaying || phase != CatStackPhase.swinging) return;

    GameAudio.playJump();
    _lockedCameraX = _aimX;
    _dismissSwingingCat();
    phase = CatStackPhase.falling;
    _fallTimer = 0;
    _stabilizeTimer = 0;
    _landCounter = 0;
    _stackStableCounter = 0;

    final cat = StackedCatBody(
      spriteIndex: spriteIndex,
      position: position,
      angle: angle,
      linearVelocity: linearVelocity,
    );
    stackedCats.add(cat);
    world.add(cat);
    _invalidateSupportCache();
  }

  void _invalidateSupportCache() => _supportBelowCache.clear();

  List<StackedCatBody> _settledByHeight() {
    final settled = stackedCats.where((c) => c.settled).toList();
    settled.sort((a, b) => a.body.position.y.compareTo(b.body.position.y));
    return settled;
  }

  List<StackedCatBody> _dynamicStackHead() {
    final settled = _settledByHeight();
    if (settled.isEmpty) return const [];
    return [settled.first];
  }

  /// Kule tabanı (en alttaki yerleşmiş kedi).
  StackedCatBody? get _baseSettledCat {
    final settled = stackedCats.where((c) => c.settled);
    if (settled.isEmpty) return null;
    return settled.reduce(
      (a, b) => a.body.position.y > b.body.position.y ? a : b,
    );
  }

  void _clampCatAngle(StackedCatBody cat) {
    final angle = cat.body.angle.clamp(
      -GameConfig.maxSettledAngleRad,
      GameConfig.maxSettledAngleRad,
    );
    if ((cat.body.angle - angle).abs() < 0.001) return;
    cat.body.setTransform(
      Vector2(cat.body.position.x, cat.body.position.y),
      angle,
    );
    cat.body.angularVelocity = 0;
  }

  void _lockSettledStack() {
    _invalidateSupportCache();
    final settled = _settledByHeight();
    for (var i = settled.length - 1; i >= 0; i--) {
      final cat = settled[i];
      cat.freezeAsStatic();
      _clampCatAngle(cat);
      _weldSettledCat(cat);
    }
  }

  Body? get _groundBody {
    for (final child in world.children) {
      if (child is GroundBody) return child.body;
    }
    return null;
  }

  bool _catsOverlapHorizontally(StackedCatBody a, StackedCatBody b) {
    final dx = (a.body.position.x - b.body.position.x).abs();
    return dx <
        (a.catInfo.contentHalfW + b.catInfo.contentHalfW) *
            GameConfig.stackSupportOverlapFactor;
  }

  bool _isStackedOn(StackedCatBody upper, StackedCatBody lower) {
    if (lower.body.position.y <= upper.body.position.y) return false;
    if (!_catsOverlapHorizontally(upper, lower)) return false;
    final feetGap = _catFeetY(upper) - _catHeadY(lower);
    return feetGap >= -0.55 && feetGap <= GameConfig.stackSupportMaxFeetGap;
  }

  double _catFeetY(StackedCatBody cat) =>
      cat.body.position.y + cat.catInfo.stackFeetRestOffsetY;

  double _catHeadY(StackedCatBody cat) =>
      cat.body.position.y + cat.catInfo.stackSupportTopOffsetY;

  /// Canlı kedi pozisyonlarından kule tepesi (kamera / continue için).
  double _computeLiveStackTopY() {
    if (stackedCats.isEmpty) return _platformTopY;
    var top = double.infinity;
    for (final cat in stackedCats) {
      top = math.min(top, _catHeadY(cat));
    }
    return top;
  }

  void _snapCameraToStack() {
    stackTopY = _computeLiveStackTopY();
    final targetX = stackedCats.where((c) => c.settled).length >= 2
        ? _computeCameraTargetX()
        : 0.0;
    final targetY = stackTopY - GameConfig.cameraLeadAboveStack;
    camera.viewfinder.position = Vector2(targetX, targetY);
    _lockedCameraX = targetX;
  }

  void _applyStabilizingDamping() {
    final fall = _activeFall;
    final activeHead = _dynamicStackHead().toSet();
    for (final cat in stackedCats) {
      final isActivePair =
          identical(cat, fall) || activeHead.contains(cat);
      cat.body.linearDamping = isActivePair
          ? GameConfig.stabilizingLinearDamping
          : GameConfig.settledLinearDamping;
      cat.body.angularDamping = isActivePair
          ? GameConfig.stabilizingAngularDamping
          : GameConfig.settledAngularDamping;
    }
  }

  StackedCatBody? _landingSupportFor(StackedCatBody cat) => _topSettledCat;

  bool _isTowerUnstable() {
    if (_hasTowerFailed()) return true;

    final cat = _activeFall;
    if (cat != null && !cat.settled) {
      if (cat.body.angle.abs() > GameConfig.uprightCorrectionMaxAngleRad) {
        return true;
      }
      if (cat.body.angularVelocity.abs() >
          GameConfig.stackStableAngular * 3.5) {
        return true;
      }
    }
    return false;
  }

  /// İki kedi için yatay oturma mesafesi — dar görsel gövde / PNG boşluğu affı.
  double _landingReach(StackedCatBody a, StackedCatBody b) {
    final wa = a.catInfo.contentWorldSize.x;
    final wb = b.catInfo.contentWorldSize.x;
    return math.max(wa, wb) * GameConfig.stackLandHorizontalFactor;
  }

  bool _isRestingOnSupport(StackedCatBody cat, StackedCatBody? support) {
    if (_isTowerUnstable()) return false;

    if (support == null) {
      final catBottom = _catFeetY(cat);
      return catBottom >= _platformTopY - 0.35 &&
          catBottom <= _platformTopY + 0.45 &&
          cat.body.linearVelocity.length < GameConfig.settleSpeed * 2.5 &&
          cat.body.angle.abs() < GameConfig.uprightCorrectionMaxAngleRad;
    }

    final dx = (cat.body.position.x - support.body.position.x).abs();
    if (dx > _landingReach(cat, support)) return false;

    final catBottom = _catFeetY(cat);
    final stackTop = _catHeadY(support);
    // Dikey pencere geniş — ayak/sırt oranındaki PNG boşluğunu affeder.
    if (catBottom < stackTop - cat.catInfo.contentHalfH * 0.65) return false;
    if (catBottom > stackTop + cat.catInfo.contentHalfH * 0.9) return false;
    if (cat.body.angle.abs() > GameConfig.uprightCorrectionMaxAngleRad) {
      return false;
    }
    if (support.body.angle.abs() > GameConfig.uprightCorrectionMaxAngleRad) {
      return false;
    }

    return cat.body.linearVelocity.length < GameConfig.settleSpeed * 3.0;
  }

  /// Fizik konumuna dokunmadan sadece hızları sıfırla.
  void _finalizeCatLanding(StackedCatBody cat) {
    cat.body.linearVelocity.setZero();
    cat.body.angularVelocity = 0;
    _clampCatAngle(cat);
    for (final head in _dynamicStackHead()) {
      head.body.linearVelocity.setZero();
      head.body.angularVelocity = 0;
    }
  }

  bool _canQuickSettle(StackedCatBody cat, StackedCatBody? support) {
    if (!_isActiveCatValidlyStacked()) return false;
    final maxAngle = GameConfig.quickSettleMaxAngleRad;
    if (cat.body.angle.abs() > maxAngle) return false;
    if (support != null && support.body.angle.abs() > maxAngle) return false;
    return true;
  }

  void _completeCatPlacement(StackedCatBody cat) {
    final landingSupport = _landingSupportFor(cat);
    _finalizeCatLanding(cat);
    cat.markSettled();
    _invalidateSupportCache();
    _weldToSupport(cat, landingSupport);
    score++;
    if (score > highScore) {
      highScore = score;
      ScoreStorage.saveHighScore(highScore);
    }
    stackTopY = _catHeadY(cat);
    onStateChanged?.call();
    _spawnSwingingCat();
  }

  StackedCatBody? _findCatSupportBelow(StackedCatBody cat) {
    final cached = _supportBelowCache[cat];
    if (_supportBelowCache.containsKey(cat)) return cached;

    StackedCatBody? best;
    var bestY = double.infinity;

    for (final other in stackedCats) {
      if (identical(other, cat) || !other.settled) continue;
      if (!_isStackedOn(cat, other)) continue;
      if (other.body.position.y < bestY) {
        bestY = other.body.position.y;
        best = other;
      }
    }
    _supportBelowCache[cat] = best;
    return best;
  }

  Vector2 _weldAnchorFor(StackedCatBody cat, StackedCatBody? below) {
    if (below != null) {
      final catBottom = _catFeetY(cat);
      final supportTop = _catHeadY(below);
      return Vector2(cat.body.position.x, (catBottom + supportTop) * 0.5);
    }
    return Vector2(cat.body.position.x, _platformTopY);
  }

  void _weldToSupport(StackedCatBody cat, StackedCatBody? below) {
    if (!cat.settled) return;

    StackedCatBody? support = below;
    if (support != null && !_isStackedOn(cat, support)) {
      support = null;
    }
    support ??= _findCatSupportBelow(cat);

    Body? supportBody;
    if (support != null) {
      supportBody = support.body;
    } else {
      final catBottom = _catFeetY(cat);
      if (catBottom > _platformTopY + 0.55) return;
      supportBody = _groundBody;
    }
    if (supportBody == null) return;

    cat.weldTo(supportBody, _weldAnchorFor(cat, support));
  }

  void _weldSettledCat(StackedCatBody cat) => _weldToSupport(cat, null);

  void _spawnSwingingCat() {
    if (!_isPlaying) return;

    _dismissSwingingCat();
    final spriteIndex = _pickSpriteIndex();
    if (stackedCats.isEmpty && score == 0) {
      _setStackTopOnGround(spriteIndex);
    }

    swingingCat = SwingingCat(spriteIndex: spriteIndex, score: score);
    world.add(swingingCat!);
    phase = CatStackPhase.swinging;
    _lockSettledStack();
  }

  void _dismissSwingingCat() {
    swingingCat?.removeFromParent();
    swingingCat = null;
    for (final cat in world.children.whereType<SwingingCat>().toList()) {
      cat.removeFromParent();
    }
  }

  int _pickSpriteIndex() {
    if (GameConfig.catSpriteCount <= 1) return 0;

    var index = _random.nextInt(GameConfig.catSpriteCount);
    while (index == _lastSpriteIndex) {
      index = _random.nextInt(GameConfig.catSpriteCount);
    }
    _lastSpriteIndex = index;
    return index;
  }

  void _setStackTopOnGround(int spriteIndex) {
    final info = CatSprites.infoForIndex(spriteIndex);
    stackTopY = _platformTopY - info.stackFeetRestOffsetY + info.stackSupportTopOffsetY;
  }

  @override
  void update(double dt) {
    // Game over inişi: UI gelmeden önce kamera zemine kayar.
    if (_awaitingGameOverUi) {
      _tickPendingGameOverDescent(dt);
      return;
    }

    if (phase == CatStackPhase.gameOver) {
      _tickGameOver(dt);
      return;
    }

    if (_postContinueGraceTimer > 0) {
      _postContinueGraceTimer = math.max(0, _postContinueGraceTimer - dt);
    }

    if (!_gameOverDescentActive) {
      _updateCamera();
    } else {
      _updateGameOverCamera(dt);
    }

    if (phase == CatStackPhase.falling) {
      _fallTimer += dt;
      _invalidateSupportCache();
      _updateFalling(dt);
      _checkTowerCollapsed(dt);
    } else if (phase == CatStackPhase.stabilizing) {
      _stabilizeTimer += dt;
      _invalidateSupportCache();
      _updateStabilizing(dt);
      _checkTowerCollapsed(dt);
    } else if (phase == CatStackPhase.swinging) {
      _collapseCheckFrame++;
      if (_collapseCheckFrame >= GameConfig.collapseCheckIntervalFrames) {
        _collapseCheckFrame = 0;
        _checkTowerCollapsed(
          dt * GameConfig.collapseCheckIntervalFrames,
        );
      }
    }

    if (_awaitingGameOverUi) {
      _tickPendingGameOverDescent(dt);
      return;
    }

    if (phase == CatStackPhase.gameOver) {
      _tickGameOver(dt);
      return;
    }

    super.update(dt);
  }

  /// Kaybetince önce aşağı kaydır, sonra continue / game over UI.
  void _tickPendingGameOverDescent(double dt) {
    if (!_stackReleasedForCollapse) {
      _releaseLockedStack();
      _stackReleasedForCollapse = true;
    }
    super.update(dt);
    _updateGameOverCamera(dt);

    final travel = (_gameOverPanTargetY - _gameOverPanStartY).abs();
    final done = _gameOverPanT >= 1.0 ||
        (travel < 0.4 && _gameOverPanT >= 0.15) ||
        _gameOverPanT >= 0.92;
    if (!done) return;

    _awaitingGameOverUi = false;
    if (_offerContinueOnUi && canOfferAdContinue) {
      _openContinueAdMenu();
    } else {
      _finalizeGameOver();
    }
  }

  void _tickGameOver(double dt) {
    _dismissSwingingCat();
    super.update(dt);
    _updateGameOverCamera(dt);
  }

  /// Yakın kaçırmalarda kuleye doğru hafif mıknatıs — oturmayı kolaylaştırır.
  void _applyLandingAssist(StackedCatBody cat, double dt) {
    final top = _topSettledCat;
    if (top == null || cat.settled) return;

    final catBottom = _catFeetY(cat);
    final stackTop = _catHeadY(top);
    // Henüz kule seviyesine yaklaşmamışsa çekme.
    if (catBottom < stackTop - cat.catInfo.contentHalfH * 1.2) return;

    final dx = top.body.position.x - cat.body.position.x;
    final reach =
        _landingReach(cat, top) * GameConfig.landingAssistReachFactor;
    if (dx.abs() > reach || dx.abs() < 0.04) return;

    final t = 1.0 - (dx.abs() / reach);
    final pull = dx.sign *
        GameConfig.landingAssistStrength *
        t *
        t *
        dt;
    final v = cat.body.linearVelocity;
    cat.body.linearVelocity = Vector2(v.x + pull, v.y);
  }

  void _updateFalling(double dt) {
    if (!_isPlaying || phase != CatStackPhase.falling) return;

    final cat = _activeFall;
    if (cat == null) return;

    _applyLandingAssist(cat, dt);

    if (_hasActiveCatMissedStack()) {
      _triggerGameOver();
      return;
    }

    if (_hasTowerFailed()) {
      _handleTowerCollapse(dt);
      return;
    }

    final support = _landingSupportFor(cat);
    if (_isRestingOnSupport(cat, support)) {
      if (_canQuickSettle(cat, support)) {
        _completeCatPlacement(cat);
        return;
      }
      phase = CatStackPhase.stabilizing;
      _stabilizeTimer = 0;
      _stackStableCounter = 0;
      _applyStabilizingDamping();
      return;
    }

    if (cat.body.linearVelocity.length < GameConfig.settleSpeed) {
      _landCounter++;
      cat.body.linearDamping = GameConfig.settledLinearDamping;
      cat.body.angularDamping = GameConfig.settledAngularDamping;
    } else {
      _landCounter = 0;
    }

    if (_landCounter >= GameConfig.settleFrames) {
      phase = CatStackPhase.stabilizing;
      _stabilizeTimer = 0;
      _stackStableCounter = 0;
      _applyStabilizingDamping();
      return;
    }

    if (_fallTimer > GameConfig.missTimeout && _hasActiveCatMissedStack()) {
      _triggerGameOver();
    }
  }

  void _updateStabilizing(double dt) {
    if (!_isPlaying || phase != CatStackPhase.stabilizing) return;

    final cat = _activeFall;
    if (cat == null) return;

    if (_hasTowerFailed()) {
      _handleTowerCollapse(dt);
      return;
    }

    if (_isStackStable()) {
      _stackStableCounter++;
    } else {
      _stackStableCounter = 0;
    }

    final ready = _stackStableCounter >= GameConfig.stackStableFrames;
    final timedOut = _stabilizeTimer >= GameConfig.maxStabilizeSeconds &&
        _isStackMostlyStable();

    if (ready || timedOut) {
      // Kule ayaktaysa ve kedi üstte oturuyorsa skor say — sadece gerçek miss'te game over.
      if (_hasActiveCatMissedStack()) {
        _triggerGameOver();
        return;
      }
      if (!_isActiveCatValidlyStacked()) {
        _triggerGameOver();
        return;
      }

      _completeCatPlacement(cat);
    }
  }

  bool _isStackStable() {
    final cat = _activeFall;
    if (cat == null || cat.settled) return true;

    if (cat.body.linearVelocity.length > GameConfig.stackStableSpeed) {
      return false;
    }
    if (cat.body.angularVelocity.abs() > GameConfig.stackStableAngular) {
      return false;
    }

    for (final head in _dynamicStackHead()) {
      if (head.body.linearVelocity.length > GameConfig.stackStableSpeed) {
        return false;
      }
      if (head.body.angularVelocity.abs() > GameConfig.stackStableAngular) {
        return false;
      }
    }
    return true;
  }

  bool _isStackMostlyStable() {
    if (stackedCats.isEmpty) return true;
    var total = 0.0;
    for (final cat in stackedCats) {
      total += cat.body.linearVelocity.length;
    }
    return total / stackedCats.length < GameConfig.stackStableSpeed * 2.2;
  }

  StackedCatBody? get _topSettledCat {
    final settled = stackedCats.where((c) => c.settled);
    if (settled.isEmpty) return null;
    return settled.reduce(
      (a, b) => a.body.position.y < b.body.position.y ? a : b,
    );
  }

  /// Düşen kedi kuleyi kaçırdı mı veya platformdan tamamen düştü mü?
  bool _hasActiveCatMissedStack() {
    final cat = _activeFall;
    if (cat == null || cat.settled) return false;

    final catTop = _catHeadY(cat);
    if (catTop > _platformTopY + GameConfig.fellBelowPlatformTop) {
      return true;
    }

    final topCat = _topSettledCat;
    if (topCat == null) return false;

    final catBottom = _catFeetY(cat);
    final stackLandingY = _catHeadY(topCat);
    if (catBottom < stackLandingY - cat.catInfo.contentHalfH * 0.4) {
      return false;
    }

    final dx = (cat.body.position.x - topCat.body.position.x).abs();
    final onStack = dx < _landingReach(cat, topCat) &&
        cat.body.position.y <=
            topCat.body.position.y + cat.catInfo.stackFeetRestOffsetY;
    if (onStack) return false;

    if (cat.body.linearVelocity.length > GameConfig.settleSpeed * 3) {
      return false;
    }

    final onGround = catBottom > _platformTopY - 0.25;
    final besideStack = dx >
        math.max(
              cat.catInfo.contentWorldSize.x,
              topCat.catInfo.contentWorldSize.x,
            ) *
            GameConfig.stackMissHorizontalFactor;
    final lowEnough = cat.body.position.y >
        topCat.body.position.y + topCat.catInfo.stackSupportTopOffsetY;

    return onGround && besideStack && lowEnough;
  }

  /// Kule yıkıldı mı?
  bool _hasTowerFailed() {
    if (_hasSettledCatFallenOff(unblockDuringStabilize: true)) return true;

    if (phase == CatStackPhase.stabilizing && !_isStackMostlyStable()) {
      return false;
    }

    if (_hasClearlyFallenSettledCat()) return true;
    if (_hasSettledCatBesideStack()) return true;
    return false;
  }

  bool _isSupportedInStack(StackedCatBody cat) {
    final below = _findCatSupportBelow(cat);
    if (below == null) {
      return _catFeetY(cat) <= _platformTopY + 0.45;
    }

    final dx = (cat.body.position.x - below.body.position.x).abs();
    return dx <= _landingReach(cat, below) * 1.1;
  }

  /// Düşen kedi gerçekten kuleye / platforma oturdu mu?
  bool _isActiveCatValidlyStacked() {
    final cat = _activeFall;
    if (cat == null) return true;

    final topCat = _topSettledCat;
    if (topCat == null) {
      final catBottom = _catFeetY(cat);
      return catBottom <= _platformTopY + 0.4 &&
          catBottom >= _platformTopY - 0.55;
    }

    final catBottom = _catFeetY(cat);
    final stackTop = _catHeadY(topCat);
    if (catBottom > stackTop + cat.catInfo.contentHalfH * 0.75) {
      return false;
    }

    final dx = (cat.body.position.x - topCat.body.position.x).abs();
    return dx <= _landingReach(cat, topCat);
  }

  /// Yerleşmiş kedi belirgin şekilde yatmış mı?
  bool _hasClearlyFallenSettledCat() {
    for (final cat in stackedCats) {
      if (!cat.settled) continue;
      if (cat.body.angle.abs() <= GameConfig.fallenAngleRad) continue;

      if (_isSupportedInStack(cat) &&
          cat.body.angle.abs() < GameConfig.stackLeanMaxRad) {
        continue;
      }

      return true;
    }
    return false;
  }

  /// Yerleşmiş kedi kule yanında / platformda devrilmiş mi?
  bool _hasSettledCatBesideStack({bool unblockDuringStabilize = false}) {
    if (stackedCats.length < 2) return false;
    if (!unblockDuringStabilize &&
        phase == CatStackPhase.stabilizing &&
        !_isStackMostlyStable()) {
      return false;
    }

    final cats = stackedCats.where((c) => c.settled).toList();
    if (cats.length < 2) return false;

    for (final cat in cats) {
      final below = _findCatSupportBelow(cat);
      if (below == null) continue;

      final dx = (cat.body.position.x - below.body.position.x).abs();
      final dy = (cat.body.position.y - below.body.position.y).abs();
      final sameLevel = dy < cat.catInfo.contentHalfH * 0.55;

      if (sameLevel &&
          dx >
              cat.catInfo.contentWorldSize.x *
                  GameConfig.stackBesideHorizontalFactor) {
        return true;
      }
    }
    return false;
  }

  /// Yerleşmiş kedi kuleden kopup yere düştü mü?
  bool _hasSettledCatFallenOff({bool unblockDuringStabilize = false}) {
    if (!unblockDuringStabilize &&
        phase == CatStackPhase.stabilizing &&
        !_isStackMostlyStable()) {
      return false;
    }

    for (final cat in stackedCats.where((c) => c.settled)) {
      final catTop = _catHeadY(cat);
      if (catTop > _platformTopY + GameConfig.fellBelowPlatformTop) {
        return true;
      }
    }
    return false;
  }

  void _checkTowerCollapsed(double dt) {
    if (_postContinueGraceTimer > 0) return;

    if (!_hasTowerFailed()) {
      _collapseTimer = 0;
      return;
    }

    if (_hasClearlyFallenSettledCat() ||
        _hasSettledCatFallenOff(unblockDuringStabilize: true)) {
      _triggerGameOver();
      return;
    }

    _collapseTimer += dt;
    final grace = _hasClearlyFallenSettledCat()
        ? GameConfig.collapseGraceSeconds * 0.5
        : GameConfig.collapseGraceSeconds;
    if (_collapseTimer >= grace) {
      _triggerGameOver();
    }
  }

  void _releaseLockedStack() {
    for (final cat in stackedCats.where((c) => c.settled)) {
      cat.destroySupportJoint();
      if (cat.isPhysicsStatic) cat.promoteToDynamic();
      cat.body.linearDamping = GameConfig.fallingLinearDamping;
      cat.body.angularDamping = GameConfig.fallingAngularDamping;
    }
    _invalidateSupportCache();
  }

  void _handleTowerCollapse(double dt) {
    if (!_stackReleasedForCollapse) {
      _releaseLockedStack();
      _stackReleasedForCollapse = true;
    }
    _checkTowerCollapsed(dt);
  }

  void _calmStackForGameOver() {
    for (final cat in stackedCats) {
      cat.dampForGameOver();
    }
  }

  void _playGameOverSound() {
    if (_gameOverSoundPlayed) return;
    _gameOverSoundPlayed = true;
    GameAudio.playGameOver();
  }

  void _beginGameOverDescent() {
    _gameOverDescentActive = true;
    // Kule tepesinden zemine doğru kaydır (mevcut bakıştan).
    final current = camera.viewfinder.position;
    _lockedCameraX = current.x;
    _gameOverPanStartY = current.y;
    _gameOverPanStartX = current.x;
    _gameOverPanTargetY = _gameOverCameraTargetY();
    // Hedef neredeyse aynıysa yine de hafif aşağı it.
    if ((_gameOverPanTargetY - _gameOverPanStartY).abs() < 0.5) {
      _gameOverPanTargetY = _gameOverPanStartY + 4.5;
    }
    _gameOverPanT = 0;
  }

  void _triggerGameOver() {
    if (phase == CatStackPhase.gameOver || _awaitingGameOverUi) return;
    if (overlays.isActive(continueAdOverlay) ||
        overlays.isActive(gameOverOverlay)) {
      return;
    }

    _playGameOverSound();
    _beginGameOverDescent();
    _offerContinueOnUi = canOfferAdContinue;
    _awaitingGameOverUi = true;
    overlays.remove(hudOverlay);
    onStateChanged?.call();
  }

  void _openContinueAdMenu() {
    AdManager.instance.resetWatchSession();
    AdManager.instance.loadRewardedAd(force: true);
    _adSessionRewardHandled = false;
    // Kamerayı yukarı snap etme — iniş kalsın.
    pauseEngine();
    overlays.remove(hudOverlay);
    overlays.add(continueAdOverlay);
    onStateChanged?.call();
  }

  void onAdContinueReward() {
    if (_adSessionRewardHandled) return;
    _adSessionRewardHandled = true;
    continueAfterAd();
  }

  void onAdContinueCancelled() {
    if (_adSessionRewardHandled) return;
    _adSessionRewardHandled = true;
    showFinalGameOver();
  }

  /// Tam ekran reklam gösterilmeden önce motoru devam ettir (reklam görünürlüğü).
  void resumeForRewardedAd() {
    resumeEngine();
  }

  /// Reklam açılamazsa continue menüsünde motoru tekrar duraklat.
  void pauseForContinueMenu() {
    if (overlays.isActive(continueAdOverlay)) {
      pauseEngine();
    }
  }

  void continueAfterAd() {
    adRevivesUsed++;
    _restoreStackAfterContinue();
    _collapseTimer = 0;
    _stackReleasedForCollapse = false;
    _gameOverDescentActive = false;
    _gameOverPanT = 1;
    _awaitingGameOverUi = false;
    _gameOverSoundPlayed = false;
    _landCounter = 0;
    _stackStableCounter = 0;
    _fallTimer = 0;
    _stabilizeTimer = 0;
    _lockedCameraX = 0;
    _postContinueGraceTimer = GameConfig.postContinueGraceSeconds;

    phase = CatStackPhase.swinging;
    overlays.remove(continueAdOverlay);
    overlays.add(hudOverlay);
    resumeEngine();
    GameAudio.prepareGameOver();
    _snapCameraToStack();
    _spawnSwingingCat();
    GameAudio.playGameplayMusic();
    onStateChanged?.call();
  }

  void showFinalGameOver() {
    if (phase == CatStackPhase.gameOver) return;
    overlays.remove(continueAdOverlay);
    resumeEngine();
    _finalizeGameOver();
  }

  void _restoreStackAfterContinue() {
    final active = _activeFall;
    if (active != null && !active.settled) {
      active.removeFromParent();
      stackedCats.remove(active);
    }

    for (final cat in List<StackedCatBody>.from(stackedCats)) {
      if (_catFeetY(cat) > _platformTopY + GameConfig.fellBelowPlatformTop) {
        cat.removeFromParent();
        stackedCats.remove(cat);
      }
    }
    _invalidateSupportCache();

    for (final cat in stackedCats) {
      _finalizeCatLanding(cat);
      cat.markSettled();
      _weldToSupport(cat, null);
    }
    if (stackedCats.isNotEmpty) {
      _lockSettledStack();
    }
    stackTopY = _computeLiveStackTopY();
  }

  void _finalizeGameOver() {
    if (phase == CatStackPhase.gameOver) return;

    _calmStackForGameOver();
    _playGameOverSound();
    // İniş yarım kaldıysa tamamla / yeniden başlat.
    if (!_gameOverDescentActive || _gameOverPanT >= 1) {
      _beginGameOverDescent();
    }
    phase = CatStackPhase.gameOver;
    _awaitingGameOverUi = false;
    _landCounter = 0;
    _stackStableCounter = 0;
    _fallTimer = 0;
    _stabilizeTimer = 0;
    _collapseTimer = 0;
    _dismissSwingingCat();

    overlays.remove(hudOverlay);
    overlays.remove(continueAdOverlay);
    overlays.add(gameOverOverlay);
    onStateChanged?.call();
  }

  double _gameOverCameraTargetY() {
    final visibleHalfHeight =
        camera.viewport.size.y / (2 * camera.viewfinder.zoom);
    return GameConfig.groundY -
        visibleHalfHeight * (1 - GameConfig.gameOverGroundViewportRatio);
  }

  void _updateGameOverCamera(double dt) {
    if (_gameOverPanT >= 1) return;
    _gameOverPanT = (_gameOverPanT + dt / GameConfig.gameOverPanDuration)
        .clamp(0.0, 1.0);
    final t = 1 - math.pow(1 - _gameOverPanT, 3).toDouble();
    final y = _gameOverPanStartY + (_gameOverPanTargetY - _gameOverPanStartY) * t;
    camera.viewfinder.position = Vector2(_gameOverPanStartX, y);
  }

  void restart() {
    GameAudio.stopAll();
    overlays.remove(gameOverOverlay);
    overlays.add(hudOverlay);

    for (final cat in List<StackedCatBody>.from(stackedCats)) {
      cat.removeFromParent();
    }
    stackedCats.clear();
    _dismissSwingingCat();
    _invalidateSupportCache();
    _skyBackground.resetClimb();
    _collapseCheckFrame = 0;
    _stackReleasedForCollapse = false;

    phase = CatStackPhase.swinging;
    score = 0;
    adRevivesUsed = 0;
    _adSessionRewardHandled = false;
    _lastSpriteIndex = null;
    _fallTimer = 0;
    _stabilizeTimer = 0;
    _landCounter = 0;
    _stackStableCounter = 0;
    _collapseTimer = 0;
    _postContinueGraceTimer = 0;
    _gameOverSoundPlayed = false;
    _gameOverDescentActive = false;
    _gameOverPanT = 1;
    _awaitingGameOverUi = false;
    _lockedCameraX = 0;

    camera.viewfinder.position = Vector2.zero();
    _spawnSwingingCat();
    _updateCamera(instant: true);
    GameAudio.playGameplayMusic();
    onStateChanged?.call();
  }

  void _updateCamera({bool instant = false}) {
    final targetX = phase == CatStackPhase.swinging
        ? _computeCameraTargetX()
        : _lockedCameraX;
    final targetY = stackTopY - GameConfig.cameraLeadAboveStack;
    final current = camera.viewfinder.position;
    final panSmooth = instant ? 1.0 : GameConfig.cameraPanSmooth;
    final nextX = instant
        ? targetX
        : current.x + (targetX - current.x) * panSmooth;
    final nextY = instant ? targetY : current.y + (targetY - current.y) * 0.06;
    camera.viewfinder.position = Vector2(nextX, nextY);
  }
}
