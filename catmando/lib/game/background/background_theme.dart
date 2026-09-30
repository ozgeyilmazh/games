import 'package:flutter/material.dart';

/// Skor bölgelerine göre gökyüzü renkleri ve katman opaklıkları.
class BackgroundPalette {
  const BackgroundPalette({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.sunGlow,
    required this.gardenLayer,
    required this.cityLayer,
    required this.cloudLayer,
    required this.sunsetTint,
    required this.spaceLayer,
  });

  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color sunGlow;
  final double gardenLayer;
  final double cityLayer;
  final double cloudLayer;
  final double sunsetTint;
  final double spaceLayer;
}

class BackgroundTheme {
  BackgroundTheme._();

  static const int gardenMax = 6;
  static const int cityMax = 14;
  static const int cloudsMax = 24;
  static const int sunsetMax = 34;

  /// Ghibli tarzı yaz gökyüzü — yumuşak mavi, yeşilimsi ufuk.
  static const _garden = BackgroundPalette(
    skyTop: Color(0xFF5EB3F6),
    skyMid: Color(0xFF96D4FA),
    skyBottom: Color(0xFFC8EEB5),
    sunGlow: Color(0xFFFFF3B0),
    gardenLayer: 1,
    cityLayer: 0,
    cloudLayer: 0.22,
    sunsetTint: 0,
    spaceLayer: 0,
  );

  static const _city = BackgroundPalette(
    skyTop: Color(0xFF4DA8E8),
    skyMid: Color(0xFF87C4F0),
    skyBottom: Color(0xFFB8DDB0),
    sunGlow: Color(0xFFFFE8A3),
    gardenLayer: 0.55,
    cityLayer: 1, // forest / large trees
    cloudLayer: 0.55,
    sunsetTint: 0,
    spaceLayer: 0,
  );

  static const _clouds = BackgroundPalette(
    skyTop: Color(0xFF6AABDD),
    skyMid: Color(0xFFA8CCE8),
    skyBottom: Color(0xFFD5E8D0),
    sunGlow: Color(0xFFFFD699),
    gardenLayer: 0.15,
    cityLayer: 0.55,
    cloudLayer: 1,
    sunsetTint: 0,
    spaceLayer: 0,
  );

  static const _sunset = BackgroundPalette(
    skyTop: Color(0xFF7B5BA8),
    skyMid: Color(0xFFE8956A),
    skyBottom: Color(0xFFFFC87A),
    sunGlow: Color(0xFFFFAB76),
    gardenLayer: 0,
    cityLayer: 0.15,
    cloudLayer: 0.7,
    sunsetTint: 0.55,
    spaceLayer: 0.08,
  );

  static const _space = BackgroundPalette(
    skyTop: Color(0xFF0A0E27),
    skyMid: Color(0xFF1A2850),
    skyBottom: Color(0xFF2A1848),
    sunGlow: Color(0xFFE8E0F0),
    gardenLayer: 0,
    cityLayer: 0,
    cloudLayer: 0.15,
    sunsetTint: 0,
    spaceLayer: 1,
  );

  static BackgroundPalette paletteForScore(int score) {
    if (score < gardenMax) {
      return _lerpPalette(_garden, _city, score / gardenMax);
    }
    if (score < cityMax) {
      return _lerpPalette(_city, _clouds, (score - gardenMax) / (cityMax - gardenMax));
    }
    if (score < cloudsMax) {
      return _lerpPalette(_clouds, _sunset, (score - cityMax) / (cloudsMax - cityMax));
    }
    if (score < sunsetMax) {
      return _lerpPalette(_sunset, _space, (score - cloudsMax) / (sunsetMax - cloudsMax));
    }
    return _space;
  }

  static BackgroundPalette _lerpPalette(
    BackgroundPalette a,
    BackgroundPalette b,
    double t,
  ) {
    final clamped = t.clamp(0.0, 1.0);
    return BackgroundPalette(
      skyTop: Color.lerp(a.skyTop, b.skyTop, clamped)!,
      skyMid: Color.lerp(a.skyMid, b.skyMid, clamped)!,
      skyBottom: Color.lerp(a.skyBottom, b.skyBottom, clamped)!,
      sunGlow: Color.lerp(a.sunGlow, b.sunGlow, clamped)!,
      gardenLayer: _lerpDouble(a.gardenLayer, b.gardenLayer, clamped),
      cityLayer: _lerpDouble(a.cityLayer, b.cityLayer, clamped),
      cloudLayer: _lerpDouble(a.cloudLayer, b.cloudLayer, clamped),
      sunsetTint: _lerpDouble(a.sunsetTint, b.sunsetTint, clamped),
      spaceLayer: _lerpDouble(a.spaceLayer, b.spaceLayer, clamped),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
