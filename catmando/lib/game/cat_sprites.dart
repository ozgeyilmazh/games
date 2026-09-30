import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/services.dart';

import 'game_config.dart';

/// Tek bir kedi görseli + dünya ölçüsü (PNG piksel boyutuna göre).
class CatSpriteInfo {
  CatSpriteInfo({
    required this.sprite,
    required this.displaySprite,
    required this.pixelSize,
    required this.worldSize,
    required this.contentRect,
    required this.contentWorldSize,
    required this.contentCenterOffsetWorld,
  });

  final Sprite sprite;
  final Sprite displaySprite;
  final Vector2 pixelSize;
  final Vector2 worldSize;
  final Rect contentRect;
  final Vector2 contentWorldSize;
  final Vector2 contentCenterOffsetWorld;

  double get halfW => worldSize.x / 2;
  double get halfH => worldSize.y / 2;

  double get contentHalfW => contentWorldSize.x / 2;
  double get contentHalfH => contentWorldSize.y / 2;

  /// Gövde merkezinden kafaya (-Y).
  double get headOffsetY => contentCenterOffsetWorld.y - contentHalfH;

  /// İp bağlantı noktası — gövde merkezine göre Y (negatif = yukarıda).
  double get ropeHookOffsetY {
    final aspect = contentWorldSize.x / contentWorldSize.y;
    final inset = aspect > 1.05
        ? GameConfig.ropeHookInsetLyingRatio
        : GameConfig.ropeHookInsetSittingRatio;
    return headOffsetY + contentHalfH * 2 * inset;
  }

  /// İp kancası → fizik gövde merkezi.
  Vector2 get hookToBodyCenter => Vector2(0, -ropeHookOffsetY);

  bool get _isLyingPose => contentWorldSize.x / contentWorldSize.y > 1.05;

  double get _stackSupportFromTop => _isLyingPose
      ? GameConfig.catStackSupportLyingFromTop
      : GameConfig.catStackSupportSittingFromTop;

  double get _stackFeetFromTop => _isLyingPose
      ? GameConfig.catStackFeetLyingFromTop
      : GameConfig.catStackFeetSittingFromTop;

  /// Alttaki kedinin sırt/destek yüzeyi (gövde merkezine göre Y).
  double get stackSupportTopOffsetY =>
      contentCenterOffsetWorld.y +
      (_stackSupportFromTop - 0.5) * contentWorldSize.y;

  /// Üst kedinin ayak/pati hattı (gövde merkezine göre Y).
  double get stackFeetRestOffsetY =>
      contentCenterOffsetWorld.y +
      (_stackFeetFromTop - 0.5) * contentWorldSize.y;

  /// Yerleşince kullanılacak dikey boşluk.
  double get stackSettleGap =>
      GameConfig.catStackVerticalGap +
      contentWorldSize.y * GameConfig.catStackVerticalGapRatio;
}

/// `assets/cats/cat1.png` … `cat21.png`
class CatSprites {
  CatSprites._();

  static final List<CatSpriteInfo> _cats = [];

  static bool get isLoaded => _cats.isNotEmpty;

  static Future<void> load() async {
    if (_cats.isNotEmpty) return;
    for (var i = 1; i <= GameConfig.catSpriteCount; i++) {
      final data = await rootBundle.load('assets/cats/cat$i.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final contentRect = await _scanOpaqueBounds(image);
      final pixelSize = Vector2(image.width.toDouble(), image.height.toDouble());
      final worldSize = _pixelsToWorld(pixelSize);
      final contentWorldSize =
          _pixelsToWorld(Vector2(contentRect.width, contentRect.height));
      final imageCenter = pixelSize / 2;
      final contentCenter = contentRect.center;
      final contentCenterOffsetWorld = _pixelsToWorld(
        Vector2(
          contentCenter.dx - imageCenter.x,
          contentCenter.dy - imageCenter.y,
        ),
      );
      final displaySprite = Sprite(
        image,
        srcPosition: Vector2(contentRect.left, contentRect.top),
        srcSize: Vector2(contentRect.width, contentRect.height),
      );

      _cats.add(
        CatSpriteInfo(
          sprite: Sprite(image),
          displaySprite: displaySprite,
          pixelSize: pixelSize,
          worldSize: worldSize,
          contentRect: contentRect,
          contentWorldSize: contentWorldSize,
          contentCenterOffsetWorld: contentCenterOffsetWorld,
        ),
      );
    }
  }

  static Future<Rect> _scanOpaqueBounds(
    ui.Image image, {
    int alphaThreshold = 48,
  }) async {
    final w = image.width;
    final h = image.height;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      return Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    }

    var minX = w;
    var minY = h;
    var maxX = 0;
    var maxY = 0;
    var found = false;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (data.getUint8(i + 3) >= alphaThreshold) {
          found = true;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (!found) {
      return Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    }

    return Rect.fromLTWH(
      minX.toDouble(),
      minY.toDouble(),
      (maxX - minX + 1).toDouble(),
      (maxY - minY + 1).toDouble(),
    );
  }

  static Vector2 _pixelsToWorld(Vector2 pixels) {
    final scale = 1 / GameConfig.catPixelsPerWorldUnit;
    return pixels * scale;
  }

  static CatSpriteInfo infoForIndex(int index) =>
      _cats[index % _cats.length];

  static Sprite spriteForIndex(int index) => infoForIndex(index).sprite;

  static Vector2 worldSizeForIndex(int index) =>
      infoForIndex(index).worldSize;

  static double get maxHalfW {
    if (_cats.isEmpty) return 0.55;
    return _cats.map((c) => c.contentHalfW).reduce((a, b) => a > b ? a : b);
  }
}
