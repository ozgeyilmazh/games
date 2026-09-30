import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../cat_stack_game.dart';
import '../game_config.dart';
import 'background_theme.dart';

/// Tam ekran gökyüzü + parallax katmanları (fizik dünyasından bağımsız).
class SkyBackground extends Component with HasGameReference<CatStackGame> {
  static const double _gardenParallax = 0.52;
  static const double _cloudParallax = 0.22;
  static const double _spaceParallax = 0.08;

  final math.Random _rng = math.Random(42);

  late List<_Star> _stars;
  late List<_Cloud> _clouds;
  late List<_VillageSlot> _villageSlots;
  late List<_SkylineSlot> _skylineSlots;
  double _smoothedClimb = 0;

  static const double _skylineGrowDuration = 1.2;

  static const double _distantHillStart = 1.8;
  static const double _distantHillEnd = 2.6;
  static const double _skylinePhaseStart = 2.8;
  static const double _skylinePhaseEnd = 4.2;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _stars = List.generate(28, (_) => _Star(_rng));
    _clouds = List.generate(6, (i) => _Cloud(_rng, i));
    _villageSlots = List.generate(2, (i) => _VillageSlot(_rng, i));
    _skylineSlots = List.generate(4, (i) => _SkylineSlot(_rng, i));
  }

  void resetClimb() => _smoothedClimb = 0;

  /// Platform üstünden kule tepesine kadar yükseklik (dünya birimi).
  double get _towerHeight {
    final platformTop = GameConfig.groundY - GameConfig.groundHalfH;
    return math.max(0, platformTop - game.stackTopY);
  }

  /// Ekran boyutuna göre bina yüksekliği ölçeği.
  double _cityHeightScale(Vector2 size) => (size.y / 760).clamp(0.95, 1.4);

  /// Kule yükseldikçe artan "yükseklik" (dünya birimi).
  double get _altitude =>
      GameConfig.groundY - game.camera.viewfinder.position.y;

  double get _pxPerWorldUnit => game.camera.viewfinder.zoom;

  @override
  void update(double dt) {
    super.update(dt);
    final target = _towerHeight;
    final speed = game.cityDescentFade < 0.99 ? 8.0 : 3.5;
    _smoothedClimb += (target - _smoothedClimb) * (1 - math.exp(-speed * dt));
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;

    final palette = BackgroundTheme.paletteForScore(game.score);
    final altitudePx = _altitude * _pxPerWorldUnit;

    _drawSkyGradient(canvas, size, palette);
    _drawGhibliAtmosphere(canvas, size, palette);

    if (palette.spaceLayer > 0) {
      _drawStars(canvas, size, altitudePx, palette.spaceLayer);
      _drawMoon(canvas, size, altitudePx, palette.spaceLayer);
    }

    final cloudClimb = _cloudClimbProgress();
    final cloudStrength = palette.cloudLayer * (1 - palette.spaceLayer * 0.85);
    if (cloudStrength > 0.02 || cloudClimb > 0.05) {
      _drawGhibliClouds(
        canvas,
        size,
        altitudePx,
        cloudStrength.clamp(0.0, 1.0),
        cloudClimb,
      );
    }

    if (palette.gardenLayer > 0 || palette.cityLayer > 0) {
      _drawLandscape(
        canvas,
        size,
        altitudePx,
        palette.gardenLayer,
        palette.cityLayer,
      );
    }

    if (palette.sunsetTint > 0) {
      _drawSunsetTint(canvas, size, palette.sunsetTint);
    }
  }

  void _drawSkyGradient(Canvas canvas, Vector2 size, BackgroundPalette palette) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyMid, palette.skyBottom],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
  }

  /// Ghibli tarzı güneş halesi + ufuk pus + ışık lekeleri.
  void _drawGhibliAtmosphere(Canvas canvas, Vector2 size, BackgroundPalette palette) {
    if (palette.spaceLayer > 0.6) return;

    final sunCenter = Offset(size.x * 0.82, size.y * 0.11);
    final sunStrength = 1 - palette.spaceLayer;

    canvas.drawCircle(
      sunCenter,
      size.x * 0.22,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.sunGlow.withValues(alpha: 0.22 * sunStrength),
            palette.sunGlow.withValues(alpha: 0.06 * sunStrength),
            const Color(0x00000000),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: size.x * 0.22)),
    );

    canvas.drawCircle(
      sunCenter,
      16,
      Paint()..color = palette.sunGlow.withValues(alpha: 0.85 * sunStrength),
    );

    // Ufuk pus — yalnızca üst yarıda, binaları örtmez.
    final hazeRect = Rect.fromLTWH(0, size.y * 0.08, size.x, size.y * 0.28);
    canvas.drawRect(
      hazeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.skyMid.withValues(alpha: 0.08 * sunStrength),
            const Color(0x00000000),
          ],
        ).createShader(hazeRect),
    );
  }

  /// Oyun platformunun backdrop üzerindeki üst kenarı.
  double _platformTopScreenY() {
    final platformTop = GameConfig.groundY - GameConfig.groundHalfH;
    return game.camera.viewfinder.localToGlobal(Vector2(0, platformTop)).y;
  }

  double _platformBottomScreenY() {
    final platformBottom = GameConfig.groundY + GameConfig.groundHalfH;
    return game.camera.viewfinder.localToGlobal(Vector2(0, platformBottom)).y;
  }

  /// Uzak tepeler + gökdelen fazları (apartmanlara dokunmaz, üstüne ekler).
  ({double distantHills, double skyline}) _climbPhases(
    double towerHeight,
    double descentFade,
  ) {
    final h = towerHeight;
    final distantHills =
        (_smoothStep(h, _distantHillStart, _distantHillEnd) * descentFade).clamp(0.0, 1.0);
    final skyline =
        (_smoothStep(h, _skylinePhaseStart, _skylinePhaseEnd) * descentFade).clamp(0.0, 1.0);
    return (distantHills: distantHills, skyline: skyline);
  }

  /// Alttan yukarı büyür, bir kez tam boy olunca kalır (replace yok).
  double _wrapCenterX(
    double center,
    double sizeX,
    double scroll,
    double parallax,
    double wrap,
  ) {
    var x = center * sizeX - scroll * parallax * 0.35;
    while (x < -100) {
      x += wrap;
    }
    while (x > sizeX + 100) {
      x -= wrap;
    }
    return x;
  }

  /// Tepe çizgisinin üstünde kalan bölgeye kırp (binalar tepenin arkasından çıkar).
  void _clipAboveHillProfile(
    Canvas canvas,
    Vector2 size,
    double platformY,
    double scroll,
    _HillProfile profile,
  ) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.x, 0);
    for (var x = size.x; x >= 0; x -= 12) {
      path.lineTo(x, _hillSurfaceY(x, platformY, scroll, profile));
    }
    path.close();
    canvas.clipPath(path);
  }

  /// Orta tepedeki ağaçlar — gövde + yaprak bitişik.
  void _drawHorizonSkyline(
    Canvas canvas,
    Vector2 size,
    double platformY,
    double scroll,
    double towerHeight,
    double skylinePhase,
    double descentFade,
  ) {
    if (skylinePhase < 0.01) return;

    final wrap = size.x + 80;
    final heightScale = _cityHeightScale(size);
    final phaseAlpha = skylinePhase.clamp(0.0, 1.0);

    for (final slot in _skylineSlots) {
      final growth = _skylineGrowth(
        towerHeight,
        slot.revealStart,
        descentFade,
      );
      if (growth < 0.01) continue;

      final centerX =
          _wrapCenterX(slot.center, size.x, scroll, slot.parallax, wrap);
      if (centerX < -120 || centerX > size.x + 120) continue;

      final b = slot.building;
      // Tepe yüzeyine dik; gökdelen boyutunu ağaç oranına indir.
      final footY = _hillSurfaceY(
        centerX,
        platformY,
        scroll,
        _HillProfiles.mid,
      );
      final treeH = (48 + b.height * 0.22 * heightScale).clamp(56.0, 130.0);
      final canopyW = (b.width * 0.55).clamp(40.0, 88.0);

      _drawNatureTree(
        canvas,
        centerX,
        footY,
        trunkW: (6 + canopyW * 0.08).clamp(6.0, 12.0),
        height: treeH,
        canopyW: canopyW,
        growth: growth * phaseAlpha,
        seed: slot.index,
      );
    }
  }

  /// Gövde tepeden yaprağa bağlı tek parça ağaç.
  void _drawNatureTree(
    Canvas canvas,
    double centerX,
    double footY, {
    required double trunkW,
    required double height,
    required double canopyW,
    required double growth,
    required int seed,
  }) {
    if (growth <= 0.005) return;
    final g = growth.clamp(0.02, 1.0);
    final h = height * g;
    final trunkH = h * 0.45;
    final canopyR = canopyW * 0.36 * (0.65 + 0.35 * g);
    final trunkTopY = footY - trunkH;
    final canopyCenterY = trunkTopY - canopyR * 0.15;

    // Gövde: yerden taç altına.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          centerX - trunkW * 0.5,
          trunkTopY,
          centerX + trunkW * 0.5,
          footY + 2,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.95),
    );

    final baseGreen = Color.lerp(
      const Color(0xFF66BB6A),
      const Color(0xFF2E7D32),
      (seed % 5) / 5.0,
    )!;
    final leafPaint = Paint()..color = baseGreen.withValues(alpha: 0.92);

    // Taç gövde ucuna oturur.
    canvas.drawCircle(Offset(centerX, canopyCenterY), canopyR, leafPaint);
    canvas.drawCircle(
      Offset(centerX - canopyR * 0.55, canopyCenterY + canopyR * 0.2),
      canopyR * 0.72,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(centerX + canopyR * 0.5, canopyCenterY + canopyR * 0.25),
      canopyR * 0.68,
      leafPaint,
    );
    canvas.drawCircle(
      Offset(centerX, canopyCenterY - canopyR * 0.35),
      canopyR * 0.55,
      leafPaint,
    );
  }

  double _skylineGrowth(
    double towerHeight,
    double revealStart,
    double descentFade,
  ) {
    final s = towerHeight - revealStart;
    if (s <= 0) return 0;
    return _smoothStep(s, 0, _skylineGrowDuration).clamp(0.0, 1.0) * descentFade;
  }

  /// Çalılar / küçük ağaçlar — köy evleri yerine.
  void _drawVillageLayer(
    Canvas canvas,
    Vector2 size,
    double platformY,
    double scroll,
  ) {
    final wrap = size.x + 80;

    for (final slot in _villageSlots) {
      final centerX =
          _wrapCenterX(slot.center, size.x, scroll, slot.parallax, wrap);
      if (centerX < -80 || centerX > size.x + 80) continue;

      final footY = _hillSurfaceY(
            centerX,
            platformY,
            scroll,
            _HillProfiles.mid,
          ) +
          10;
      _drawBushCluster(canvas, centerX, footY, slot.index);
    }
  }

  void _drawBushCluster(
    Canvas canvas,
    double centerX,
    double footY,
    int seed,
  ) {
    final greens = [
      const Color(0xFF7CB342),
      const Color(0xFF558B2F),
      const Color(0xFF9CCC65),
    ];
    // Önce kısa gövde, sonra yaprak — ayrılmasın.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(centerX - 2.5, footY - 18, centerX + 2.5, footY + 1),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF6D4C41).withValues(alpha: 0.8),
    );
    for (var i = 0; i < 3; i++) {
      final dx = (i - 1) * 14.0 + (seed % 3) * 1.5;
      final r = 12.0 + (seed + i) % 4 * 2.5;
      canvas.drawCircle(
        Offset(centerX + dx, footY - 14 - r * 0.2),
        r,
        Paint()
          ..color =
              greens[(seed + i) % greens.length].withValues(alpha: 0.9),
      );
    }
  }

  double _smoothStep(double value, double edge0, double edge1) {
    if (value <= edge0) return 0;
    if (value >= edge1) return 1;
    final t = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void _drawLandscape(
    Canvas canvas,
    Vector2 size,
    double altitudePx,
    double gardenOpacity,
    double cityOpacity,
  ) {
    final strength = [gardenOpacity, cityOpacity].reduce(math.max);
    if (strength <= 0.01) return;

    final gardenScroll = altitudePx * _gardenParallax;
    final platformY = _platformTopScreenY();
    final towerHeight = _smoothedClimb;
    final descentFade = game.cityDescentFade;
    final phases = _climbPhases(towerHeight, descentFade);
    final landscapeAlpha = strength.clamp(0.0, 1.0);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.x, size.y));

    final grassTop = platformY + size.y * 0.05;
    _drawGrassField(canvas, size, grassTop);

    _drawHillProfile(
      canvas,
      size,
      platformY,
      gardenScroll,
      _HillProfiles.far,
      const Color(0xFF90C4B0).withValues(alpha: landscapeAlpha),
      const Color(0xFF6AA892).withValues(alpha: landscapeAlpha),
      const Color(0xFF4E8878).withValues(alpha: landscapeAlpha),
    );

    if (phases.distantHills > 0.01) {
      final hillAlpha = phases.distantHills.clamp(0.0, 1.0) * landscapeAlpha;
      _drawHillProfile(
        canvas,
        size,
        platformY,
        gardenScroll,
        _HillProfiles.cityHorizon,
        const Color(0xFF98C8A8).withValues(alpha: hillAlpha),
        const Color(0xFF72B090).withValues(alpha: hillAlpha),
        const Color(0xFF589878).withValues(alpha: hillAlpha),
      );
    }

    _drawHillProfile(
      canvas,
      size,
      platformY,
      gardenScroll,
      _HillProfiles.mid,
      const Color(0xFFB0E080).withValues(alpha: landscapeAlpha),
      const Color(0xFF78D068).withValues(alpha: landscapeAlpha),
      const Color(0xFF48A858).withValues(alpha: landscapeAlpha),
    );

    // Ağaçlar orta tepenin ÜSTÜNE — gövde tepeyle örtülmesin.
    _drawHorizonSkyline(
      canvas,
      size,
      platformY,
      gardenScroll,
      towerHeight,
      phases.skyline,
      descentFade,
    );

    _drawVillageLayer(canvas, size, platformY, gardenScroll);

    _drawGroundPlatform(canvas, size, platformY);

    canvas.restore();
  }

  void _drawGrassField(
    Canvas canvas,
    Vector2 size,
    double grassTop,
  ) {
    final grassRect = Rect.fromLTWH(0, grassTop, size.x, size.y - grassTop);
    if (grassRect.height <= 0) return;

    canvas.drawRect(
      grassRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF7EC872),
            Color(0xFF64B85A),
            Color(0xFF4FA04A),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(grassRect),
    );

    final topShadowH = math.min(36.0, grassRect.height * 0.14);
    final topShadow = Rect.fromLTWH(0, grassTop, size.x, topShadowH);
    canvas.drawRect(
      topShadow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A3828).withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ).createShader(topShadow),
    );
  }

  void _drawGroundPlatform(Canvas canvas, Vector2 size, double platformY) {
    final platformBottom = _platformBottomScreenY();
    final platformHeight = platformBottom - platformY;
    if (platformHeight <= 1) return;

    final platformRect = Rect.fromLTWH(0, platformY, size.x, platformHeight);

    final castShadow = Rect.fromLTWH(0, platformY - 14, size.x, 18);
    canvas.drawRect(
      castShadow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF1E3A12).withValues(alpha: 0.28),
            const Color(0xFF142808).withValues(alpha: 0.42),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(castShadow),
    );

    canvas.drawRect(
      platformRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF9A7B6A),
            Color(0xFF735340),
            Color(0xFF5D4037),
            Color(0xFF3E2723),
          ],
          stops: const [0.0, 0.18, 0.58, 1.0],
        ).createShader(platformRect),
    );

    final grainPaint = Paint()
      ..color = const Color(0xFF4E342E).withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (var y = platformY + 5; y < platformBottom - 2; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), grainPaint);
    }

    for (var i = 0; i < (size.x / 72).ceil(); i++) {
      final x = i * 72.0 + 12;
      canvas.drawLine(
        Offset(x, platformY + 2),
        Offset(x + 6, platformBottom - 3),
        Paint()
          ..color = const Color(0xFF3E2723).withValues(alpha: 0.08)
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawLine(
      Offset(0, platformY + 0.5),
      Offset(size.x, platformY + 0.5),
      Paint()
        ..color = const Color(0xFFD7CCC8).withValues(alpha: 0.62)
        ..strokeWidth = 2.5,
    );

    canvas.drawLine(
      Offset(0, platformBottom - 1.5),
      Offset(size.x, platformBottom - 1.5),
      Paint()
        ..color = const Color(0xFF1A0E08).withValues(alpha: 0.55)
        ..strokeWidth = 3,
    );

    canvas.drawRect(
      platformRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF000000).withValues(alpha: 0.14),
            Colors.transparent,
            Colors.transparent,
            const Color(0xFF000000).withValues(alpha: 0.14),
          ],
          stops: const [0.0, 0.07, 0.93, 1.0],
        ).createShader(platformRect),
    );
  }

  double _hillSurfaceY(
    double x,
    double platformY,
    double scroll,
    _HillProfile profile,
  ) {
    final wave = profile.wave(x, scroll);
    return platformY + profile.baseOffset + wave;
  }

  void _drawHillProfile(
    Canvas canvas,
    Vector2 size,
    double platformY,
    double scroll,
    _HillProfile profile,
    Color highlightColor,
    Color midColor,
    Color shadowColor,
  ) {
    final path = Path();
    final startY = platformY + profile.baseOffset + profile.wave(0, scroll);
    path.moveTo(0, size.y);
    path.lineTo(0, startY);
    for (var x = 0.0; x <= size.x + 80; x += 48) {
      final y = platformY + profile.baseOffset + profile.wave(x, scroll);
      path.lineTo(x, y);
    }
    path.lineTo(size.x, size.y);
    path.close();

    final hillTop = platformY + profile.baseOffset - 40;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [highlightColor, midColor, shadowColor],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromLTWH(0, hillTop, size.x, size.y - hillTop)),
    );

  }

  /// Kule yükseldikçe bulut yoğunluğu (0 → 1).
  double _cloudClimbProgress() =>
      _smoothStep(_smoothedClimb, 0.2, 2.6);

  void _drawGhibliClouds(
    Canvas canvas,
    Vector2 size,
    double altitudePx,
    double opacity,
    double climb,
  ) {
    final scroll = altitudePx * _cloudParallax;
    final skyCeiling = size.y * (0.34 + 0.44 * climb);
    final maxNormalizedY = 0.2 + 0.8 * climb;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.x, skyCeiling));

    for (var i = 0; i < _clouds.length; i++) {
      final cloud = _clouds[i];
      if (cloud.y > maxNormalizedY) continue;

      final appearAt = i / _clouds.length * 0.82;
      final cloudFade = ((climb - appearAt) / 0.18).clamp(0.0, 1.0);
      if (cloudFade <= 0.01) continue;

      var ox = cloud.x * size.x + scroll * cloud.speed * 0.14;
      while (ox < -90) {
        ox += size.x + 90;
      }
      while (ox > size.x + 90) {
        ox -= size.x + 90;
      }

      final oy = cloud.y * skyCeiling + scroll * cloud.speed * 0.28;
      final strength = (opacity * 0.35 + opacity * cloudFade * 0.65) * cloud.alpha;
      _drawGhibliCloudPuff(
        canvas,
        Offset(ox, oy),
        cloud.scale * (30 + 6 * climb),
        strength,
      );
    }

    canvas.restore();
    _drawCloudMist(canvas, size, climb, opacity);
  }

  void _drawCloudMist(
    Canvas canvas,
    Vector2 size,
    double climb,
    double opacity,
  ) {
    if (climb < 0.12) return;

    final mistStrength = ((climb - 0.12) / 0.88).clamp(0.0, 1.0) * opacity;
    if (mistStrength <= 0.02) return;

    final mistRect = Rect.fromLTWH(
      0,
      size.y * (0.06 + 0.08 * (1 - climb)),
      size.x,
      size.y * (0.24 + 0.5 * climb),
    );
    canvas.drawRect(
      mistRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.1 * mistStrength),
            Colors.white.withValues(alpha: 0.2 * mistStrength),
            Colors.white.withValues(alpha: 0.05 * mistStrength),
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(mistRect),
    );
  }

  void _drawGhibliCloudPuff(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
  ) {
    if (opacity <= 0.01) return;

    final puff = Paint()..color = Colors.white.withValues(alpha: 0.58 * opacity);
    final puffSoft = Paint()..color = Colors.white.withValues(alpha: 0.42 * opacity);

    canvas.drawCircle(center, radius * 0.85, puff);
    canvas.drawCircle(center + Offset(radius * 0.5, radius * 0.05), radius * 0.6, puffSoft);
  }

  void _drawVillageHouse(
    Canvas canvas,
    double x,
    double groundY,
    _VillageHouse house,
  ) {
    final w = house.width;
    final bodyH = house.bodyHeight;
    final roofH = house.roofHeight;
    final embed = house.embedDepth;
    final bodyTop = groundY - bodyH;
    final roofBase = bodyTop;

    final wallPaint = Paint()..color = house.wallColor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, bodyTop, w, bodyH + embed),
        const Radius.circular(2),
      ),
      wallPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(x, bodyTop, w, 3),
      Paint()..color = house.trimColor,
    );

    canvas.drawRect(
      Rect.fromLTWH(x + 1, groundY + embed - 5, w - 2, 5),
      Paint()..color = _VillageHouse._softFoundation,
    );

    if (house.hasWindow) {
      _drawHouseWindow(canvas, x + w * 0.28, bodyTop + bodyH * 0.22, w * 0.22, bodyH * 0.24);
    }

    if (house.hasDoor) {
      final dw = w * 0.28;
      final dh = bodyH * 0.48;
      final dx = x + (w - dw) / 2;
      final dy = groundY - dh;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(dx, dy, dw, dh), const Radius.circular(2)),
        Paint()..color = _VillageHouse._softDoor,
      );
      canvas.drawCircle(
        Offset(dx + dw * 0.82, dy + dh * 0.52),
        1.2,
        Paint()..color = _VillageHouse._softKnob,
      );
    }

    if (house.roofStyle == _RoofStyle.flat) {
      _drawFlatBrickRoof(canvas, x, roofBase, w, roofH);
    } else {
      _drawPeakedBrickRoof(canvas, x, roofBase, w, roofH);
    }

    if (house.hasChimney && house.roofStyle == _RoofStyle.peaked) {
      final cx = x + w * 0.68;
      final cy = roofBase - roofH * 0.55;
      canvas.drawRect(
        Rect.fromLTWH(cx, cy, w * 0.11, roofH * 0.85),
        Paint()..color = _VillageHouse._softChimney,
      );
    }
  }

  void _drawHouseWindow(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(1.5)),
      Paint()..color = _VillageHouse._softWindow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(1.5)),
      Paint()
        ..color = _VillageHouse._softWindowFrame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(x + w / 2, y),
      Offset(x + w / 2, y + h),
      Paint()
        ..color = _VillageHouse._softWindowFrame
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(x, y + h / 2),
      Offset(x + w, y + h / 2),
      Paint()
        ..color = _VillageHouse._softWindowFrame
        ..strokeWidth = 0.8,
    );
  }

  void _drawPeakedBrickRoof(
    Canvas canvas,
    double x,
    double roofBase,
    double w,
    double roofH,
  ) {
    final roof = Path()
      ..moveTo(x - w * 0.1, roofBase)
      ..lineTo(x + w * 0.5, roofBase - roofH)
      ..lineTo(x + w + w * 0.1, roofBase)
      ..close();

    canvas.drawPath(
      roof,
      Paint()..color = _VillageHouse._softBricks[0],
    );
  }

  void _drawFlatBrickRoof(
    Canvas canvas,
    double x,
    double roofBase,
    double w,
    double roofH,
  ) {
    final overhang = w * 0.08;
    canvas.drawRect(
      Rect.fromLTWH(
        x - overhang,
        roofBase - roofH * 0.55,
        w + overhang * 2,
        roofH * 0.55,
      ),
      Paint()..color = _VillageHouse._softBricks[1],
    );
  }

  void _drawCityBuilding(
    Canvas canvas,
    double x,
    double groundY,
    _CityBuilding b, {
    double heightScale = 1.0,
  }) {
    if ((heightScale - 1.0).abs() > 0.01) {
      canvas.save();
      canvas.translate(x, groundY);
      canvas.scale(1, heightScale);
      canvas.translate(-x, -groundY);
    }
    switch (b.kind) {
      case _BuildingKind.skyscraper:
        _drawSkyscraper(canvas, x, groundY, b);
      case _BuildingKind.office:
        _drawOfficeBlock(canvas, x, groundY, b);
      case _BuildingKind.apartment:
        _drawApartment(canvas, x, groundY, b);
      case _BuildingKind.shop:
        _drawShop(canvas, x, groundY, b);
      case _BuildingKind.tower:
        _drawTower(canvas, x, groundY, b);
    }
    if ((heightScale - 1.0).abs() > 0.01) {
      canvas.restore();
    }
  }

  void _drawSkyscraper(
    Canvas canvas,
    double x,
    double groundY,
    _CityBuilding b,
  ) {
    final top = groundY - b.height;
    final w = b.width;
    canvas.drawRect(
      Rect.fromLTWH(x, top, w, b.height),
      Paint()..color = b.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + w * 0.12, top - 8, w * 0.76, 8),
      Paint()..color = Color.lerp(b.color, const Color(0xFF263238), 0.25)!,
    );
    _drawBuildingWindows(canvas, x, top, w, b.height, b, cols: 2);
    if (b.hasAntenna) {
      canvas.drawRect(
        Rect.fromLTWH(x + w * 0.48, top - 22, 2, 22),
        Paint()..color = const Color(0xFF455A64),
      );
    }
  }

  void _drawOfficeBlock(
    Canvas canvas,
    double x,
    double groundY,
    _CityBuilding b,
  ) {
    final top = groundY - b.height;
    final w = b.width;
    canvas.drawRect(
      Rect.fromLTWH(x, top, w, b.height),
      Paint()..color = b.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(x - 2, top - 3, w + 4, 3),
      Paint()..color = const Color(0xFF546E7A),
    );
    for (var i = 0; i < 2; i++) {
      canvas.drawRect(
        Rect.fromLTWH(x + 6 + i * (w * 0.55), top - 5, w * 0.22, 4),
        Paint()..color = const Color(0xFF78909C),
      );
    }
    _drawBuildingWindows(canvas, x, top, w, b.height, b, cols: 3);
  }

  void _drawApartment(
    Canvas canvas,
    double x,
    double groundY,
    _CityBuilding b,
  ) {
    final top = groundY - b.height;
    final w = b.width;
    canvas.drawRect(
      Rect.fromLTWH(x, top, w, b.height),
      Paint()..color = b.color,
    );
    for (var row = 0; row < b.windowRows; row++) {
      final by = top + 12 + row * 18;
      canvas.drawRect(
        Rect.fromLTWH(x + 2, by + 10, w - 4, 3),
        Paint()..color = const Color(0xFF455A64).withValues(alpha: 0.45),
      );
    }
    _drawBuildingWindows(canvas, x, top, w, b.height, b, cols: 4);
  }

  void _drawShop(
    Canvas canvas,
    double x,
    double groundY,
    _CityBuilding b,
  ) {
    final top = groundY - b.height;
    final w = b.width;
    canvas.drawRect(
      Rect.fromLTWH(x, top + 8, w, b.height - 8),
      Paint()..color = b.color,
    );
    const awningColors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047)];
    final awning = awningColors[b.seed % awningColors.length];
    canvas.drawRect(
      Rect.fromLTWH(x - 3, top, w + 6, 10),
      Paint()..color = awning,
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(x - 3 + i * (w + 6) / 3, top),
        Offset(x - 3 + i * (w + 6) / 3 + 4, top + 10),
        Paint()
          ..color = awning.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(x + 4, top + 14, w - 8, b.height - 22),
      Paint()..color = const Color(0xFF81D4FA).withValues(alpha: 0.45),
    );
  }

  void _drawTower(
    Canvas canvas,
    double x,
    double groundY,
    _CityBuilding b,
  ) {
    final top = groundY - b.height;
    final w = b.width;
    canvas.drawRect(
      Rect.fromLTWH(x + w * 0.2, top + 12, w * 0.6, b.height - 12),
      Paint()..color = b.color,
    );
    final spire = Path()
      ..moveTo(x + w * 0.2, top + 12)
      ..lineTo(x + w * 0.5, top - 18)
      ..lineTo(x + w * 0.8, top + 12)
      ..close();
    canvas.drawPath(
      spire,
      Paint()..color = Color.lerp(b.color, const Color(0xFF263238), 0.2)!,
    );
    _drawBuildingWindows(
      canvas,
      x + w * 0.2,
      top + 12,
      w * 0.6,
      b.height - 12,
      b,
      cols: 2,
    );
  }

  void _drawBuildingWindows(
    Canvas canvas,
    double x,
    double top,
    double w,
    double h,
    _CityBuilding b, {
    required int cols,
  }) {
    if (!b.litWindows) return;
    final win = Paint()..color = const Color(0xFFFFE082);
    final dim = Paint()..color = const Color(0xFF37474F).withValues(alpha: 0.35);
    for (var row = 0; row < b.windowRows; row++) {
      for (var col = 0; col < cols; col++) {
        final lit = (row + col + b.seed) % 3 != 0;
        final wx = x + 6 + col * ((w - 12) / cols);
        final wy = top + 10 + row * 16;
        if (wy + 9 > top + h - 4) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(wx, wy, 6, 8),
            const Radius.circular(0.5),
          ),
          lit ? win : dim,
        );
      }
    }
  }

  void _drawStars(
    Canvas canvas,
    Vector2 size,
    double altitudePx,
    double opacity,
  ) {
    final scroll = altitudePx * _spaceParallax;
    for (final star in _stars) {
      final x = star.x * size.x;
      final y = (star.y * size.y + scroll * star.speed) % size.y;
      final twinkle = 0.55 + 0.45 * math.sin(star.phase + scroll * 0.004);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * star.alpha * twinkle);
      canvas.drawCircle(Offset(x, y), star.radius, paint);
    }
  }

  void _drawMoon(Canvas canvas, Vector2 size, double altitudePx, double opacity) {
    if (opacity < 0.15) return;
    final scroll = altitudePx * _spaceParallax;
    final center = Offset(size.x * 0.78, size.y * 0.14 + scroll * 0.05 % 40);
    canvas.drawCircle(
      center,
      28,
      Paint()..color = Color(0xFFF5F0DC).withValues(alpha: 0.9 * opacity),
    );
    canvas.drawCircle(
      center + const Offset(-10, -4),
      24,
      Paint()..color = const Color(0xFF1A1040).withValues(alpha: 0.85 * opacity),
    );
  }

  void _drawSunsetTint(Canvas canvas, Vector2 size, double strength) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF9B6BB5).withValues(alpha: 0.12 * strength),
            const Color(0xFFFFB074).withValues(alpha: 0.22 * strength),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y))
        ..blendMode = BlendMode.softLight,
    );
  }
}

class _Star {
  _Star(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        radius = 0.6 + rng.nextDouble() * 1.6,
        alpha = 0.35 + rng.nextDouble() * 0.65,
        speed = 0.4 + rng.nextDouble() * 0.8,
        phase = rng.nextDouble() * math.pi * 2;

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final double speed;
  final double phase;
}

class _Cloud {
  _Cloud(math.Random rng, int index)
      : x = (index * 0.58 + rng.nextDouble() * 0.1) % 0.9 + 0.05,
        y = 0.05 + (index / 15) * 0.9 + rng.nextDouble() * 0.04,
        scale = 0.55 + rng.nextDouble() * 0.5,
        alpha = 0.3 + rng.nextDouble() * 0.4,
        speed = 0.25 + rng.nextDouble() * 0.45;

  final double x;
  final double y;
  final double scale;
  final double alpha;
  final double speed;
}

enum _RoofStyle { peaked, flat }

enum _BuildingKind { skyscraper, office, apartment, shop, tower }

class _VillageSlot {
  _VillageSlot(math.Random rng, this.index)
      : center = 0.22 + index * 0.48,
        parallax = 0.24 + rng.nextDouble() * 0.06,
        house = _VillageHouse(rng, index);

  final int index;
  final double center;
  final double parallax;
  final _VillageHouse house;
}

class _SkylineSlot {
  _SkylineSlot(math.Random rng, this.index)
      : center = 0.06 + index * 0.22 + rng.nextDouble() * 0.04,
        parallax = 0.10 + rng.nextDouble() * 0.06,
        revealStart = 2.9 + index * 0.45,
        building = _CityBuilding.skyline(rng, index + 30);

  final int index;
  final double center;
  final double parallax;
  final double revealStart;
  final _CityBuilding building;
}

class _HillProfile {
  const _HillProfile({
    required this.baseOffset,
    required this.amplitude,
    required this.frequency,
    required this.scrollFactor,
    required this.phase,
    this.secondaryAmplitude = 0,
    this.secondaryFrequency = 0,
  });

  final double baseOffset;
  final double amplitude;
  final double frequency;
  final double scrollFactor;
  final double phase;
  final double secondaryAmplitude;
  final double secondaryFrequency;

  double wave(double x, double scroll) {
    final primary =
        math.sin((x + scroll * scrollFactor + phase) * frequency) * amplitude;
    if (secondaryAmplitude <= 0) return primary;
    final secondary = math.sin((x + scroll * scrollFactor * 0.7) * secondaryFrequency) *
        secondaryAmplitude;
    return primary + secondary;
  }
}

class _HillProfiles {
  _HillProfiles._();

  /// Uzak, yumuşak siluet
  static const far = _HillProfile(
    baseOffset: -54,
    amplitude: 22,
    frequency: 0.010,
    scrollFactor: 1.2,
    phase: 0,
    secondaryAmplitude: 8,
    secondaryFrequency: 0.006,
  );

  /// Evlerin oturduğu orta tepe
  static const mid = _HillProfile(
    baseOffset: -30,
    amplitude: 18,
    frequency: 0.016,
    scrollFactor: 2.0,
    phase: 35,
    secondaryAmplitude: 5,
    secondaryFrequency: 0.028,
  );

  /// Uzak şehir ufku — gökdelenlerin arkasındaki yeni tepe hattı
  static const cityHorizon = _HillProfile(
    baseOffset: -68,
    amplitude: 16,
    frequency: 0.011,
    scrollFactor: 1.1,
    phase: 52,
    secondaryAmplitude: 6,
    secondaryFrequency: 0.007,
  );
}

class _VillageHouse {
  _VillageHouse(math.Random rng, int index)
      : width = 40 + rng.nextDouble() * 16,
        bodyHeight = 52 + rng.nextDouble() * 26,
        roofHeight = 18 + rng.nextDouble() * 10,
        embedDepth = 16 + rng.nextDouble() * 12,
        hasWindow = rng.nextDouble() > 0.15,
        hasDoor = rng.nextDouble() > 0.2,
        hasChimney = rng.nextDouble() > 0.55,
        roofStyle = rng.nextDouble() > 0.35 ? _RoofStyle.peaked : _RoofStyle.flat,
        wallColor = _soften(_wallColors[index % _wallColors.length]),
        trimColor = _soften(_trimColors[index % _trimColors.length]);

  static Color _soften(Color c) =>
      Color.lerp(c, const Color(0xFFECEFF1), 0.55)!;

  static const _softFoundation = Color(0xFFBCAAA4);
  static const _softDoor = Color(0xFF8D6E63);
  static const _softKnob = Color(0xFFFFE082);
  static const _softChimney = Color(0xFFBC8A7A);
  static const _softWindow = Color(0xFFB3E5FC);
  static const _softWindowFrame = Color(0xFF8D6E63);

  static const _softBricks = [
    Color(0xFFD4958A),
    Color(0xFFCC8A80),
    Color(0xFFDFA192),
    Color(0xFFC47E74),
  ];

  static const _wallColors = [
    Color(0xFFFFF3E0),
    Color(0xFFF8BBD0),
    Color(0xFFB3E5FC),
    Color(0xFFC8E6C9),
    Color(0xFFFFECB3),
    Color(0xFFD7CCC8),
    Color(0xFFE1BEE7),
    Color(0xFFBBDEFB),
  ];

  static const _trimColors = [
    Color(0xFF8D6E63),
    Color(0xFF795548),
    Color(0xFF6D4C41),
    Color(0xFF5D4037),
  ];

  final double width;
  final double bodyHeight;
  final double roofHeight;
  final double embedDepth;
  final bool hasWindow;
  final bool hasDoor;
  final bool hasChimney;
  final _RoofStyle roofStyle;
  final Color wallColor;
  final Color trimColor;
}

class _CityBuilding {
  factory _CityBuilding.skyline(math.Random rng, int index) {
    final kind = index.isEven ? _BuildingKind.skyscraper : _BuildingKind.tower;
    final (width, height, windowRows) = _dimsForKind(rng, kind);
    return _CityBuilding._(
      kind: kind,
      seed: index + 40,
      hasAntenna: kind == _BuildingKind.skyscraper && rng.nextDouble() > 0.35,
      litWindows: rng.nextDouble() > 0.15,
      color: _pickColor(rng, index + 5),
      width: width,
      height: height,
      windowRows: windowRows,
    );
  }

  _CityBuilding._({
    required this.kind,
    required this.seed,
    required this.hasAntenna,
    required this.litWindows,
    required this.color,
    required this.width,
    required this.height,
    required this.windowRows,
  });

  static (double, double, int) _dimsForKind(math.Random rng, _BuildingKind kind) {
    return switch (kind) {
      _BuildingKind.skyscraper => (
          18 + rng.nextDouble() * 12,
          135 + rng.nextDouble() * 95,
          5 + rng.nextInt(6),
        ),
      _BuildingKind.office => (
          32 + rng.nextDouble() * 16,
          58 + rng.nextDouble() * 38,
          3 + rng.nextInt(4),
        ),
      _BuildingKind.apartment => (
          38 + rng.nextDouble() * 20,
          48 + rng.nextDouble() * 32,
          2 + rng.nextInt(4),
        ),
      _BuildingKind.shop => (
          40 + rng.nextDouble() * 22,
          26 + rng.nextDouble() * 16,
          1,
        ),
      _BuildingKind.tower => (
          22 + rng.nextDouble() * 12,
          150 + rng.nextDouble() * 75,
          5 + rng.nextInt(5),
        ),
    };
  }

  static Color _pickColor(math.Random rng, int index) {
    const palette = [
      Color(0xFF8FAFC4),
      Color(0xFF9BB5A8),
      Color(0xFFB5A898),
      Color(0xFF94A8B8),
      Color(0xFFA8B0C0),
      Color(0xFF88A898),
      Color(0xFFC4B0A0),
    ];
    return Color.lerp(
      palette[index % palette.length],
      const Color(0xFFECEFF1),
      0.18 + rng.nextDouble() * 0.15,
    )!;
  }

  final _BuildingKind kind;
  final int seed;
  final bool hasAntenna;
  final bool litWindows;
  final Color color;
  final double width;
  final double height;
  final int windowRows;
}
