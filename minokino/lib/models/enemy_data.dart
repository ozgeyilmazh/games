import 'package:flame/extensions.dart';

// This class stores all the data
// necessary for creation of an enemy.
class EnemyData {
  final Image image;
  final int nFrames;
  final double stepTime;
  final Vector2 textureSize;
  final double speedX;
  final bool canFly;

  /// When true, [Dino] can stomp from above for [stompScore] instead of taking damage.
  final bool stompable;
  final Image? dieImage;
  final int dieNFrames;
  final double dieStepTime;
  final int stompScore;

  /// When set, die strip uses this frame size (else [textureSize]).
  final Vector2? dieTextureSize;

  /// Top-left of the first die frame inside [dieImage] (e.g. skip embedded run frames).
  final Vector2? dieTexturePosition;

  /// Per die frame: shift draw position along X in **texture pixels** (same space as
  /// [dieTextureSize]) so feet stay planted when art drifts inside each cell.
  /// Length must match [dieNFrames] when set.
  final List<double>? dieDrawNudgeXTexture;

  /// For [canFly]: upward offset is `random * this * textureSize.y` (default `2` like before).
  final double flyHeightRandomMultiplier;

  /// Extra scale after the global 0.6 pass (1 = unchanged).
  final double visualScale;

  const EnemyData({
    required this.image,
    required this.nFrames,
    required this.stepTime,
    required this.textureSize,
    required this.speedX,
    required this.canFly,
    this.stompable = false,
    this.dieImage,
    this.dieNFrames = 0,
    this.dieStepTime = 0.08,
    this.stompScore = 1,
    this.dieTextureSize,
    this.dieTexturePosition,
    this.dieDrawNudgeXTexture,
    this.flyHeightRandomMultiplier = 2.0,
    this.visualScale = 1.0,
  });
}
