import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '/game/dino_run.dart';

enum PlantAnim { attack, death }

/// Ground plant: [PlantAnim.attack] while alive (like a stationary hazard),
/// [PlantAnim.death] on stomp (+score), then removed.
class PlantEnemy extends SpriteAnimationGroupComponent<PlantAnim>
    with CollisionCallbacks, HasGameReference<DinoRun> {
  final double _shadowCropLocalY;

  PlantEnemy({
    required Image attackImage,
    required Image deathImage,
    required Vector2 attackTextureSize,
    required Vector2 deathTextureSize,
    double shadowCropLocalY = 13,
  }) : _shadowCropLocalY = shadowCropLocalY,
        super(
          // Plant sheets share 64px width but vary in frame heights per variant.
          scale: Vector2.all(0.6),
          anchor: Anchor.bottomLeft,
          animations: {
            PlantAnim.attack: SpriteAnimation.fromFrameData(
              attackImage,
              SpriteAnimationData.sequenced(
                amount: 7,
                stepTime: 0.08,
                textureSize: attackTextureSize,
                loop: true,
              ),
            ),
            PlantAnim.death: SpriteAnimation.fromFrameData(
              deathImage,
              SpriteAnimationData.sequenced(
                amount: 10,
                stepTime: 0.07,
                textureSize: deathTextureSize,
                loop: false,
              ),
            ),
          },
          current: PlantAnim.attack,
          removeOnFinish: const {PlantAnim.death: true},
          autoResize: true,
        );

  static const double _speedX = 118;
  static const int _stompScore = 1;

  bool _dead = false;
  bool get isDead => _dead;

  void stomp() {
    if (_dead) return;
    _dead = true;
    game.playerData.currentScore += _stompScore;
    current = PlantAnim.death;
  }

  @override
  void onMount() {
    paint.filterQuality = FilterQuality.none;
    // [anchor] uses full [size], but [render] clips off the bottom shadow strip. Without
    // shifting down, the visible plant sits that many scaled pixels above the ground line.
    position.y += _shadowCropLocalY * scale.y;
    add(
      RectangleHitbox.relative(
        Vector2.all(0.78),
        parentSize: size,
        position: Vector2(size.x * 0.22, size.y * 0.22) / 2,
      ),
    );
    super.onMount();
  }

  @override
  void update(double dt) {
    final m = game.runSpeedMultiplier;
    position.x -= _speedX * m * dt;

    if (!_dead) {
      if (position.x < -96) {
        removeFromParent();
        game.playerData.currentScore += 1;
      }
    }
    super.update(dt * m);
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) {
      super.render(canvas);
      return;
    }
    // Keep collision/ground alignment by hiding only the baked shadow strip.
    final cropH = (size.y - _shadowCropLocalY).clamp(1.0, size.y);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.x, cropH));
    super.render(canvas);
    canvas.restore();
  }
}
