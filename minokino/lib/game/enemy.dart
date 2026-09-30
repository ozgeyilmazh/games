import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '/game/dino_run.dart';
import '/models/enemy_data.dart';

// This represents an enemy in the game world.
class Enemy extends SpriteAnimationComponent
    with CollisionCallbacks, HasGameReference<DinoRun> {
  // The data required for creation of this enemy.
  final EnemyData enemyData;

  bool _dead = false;
  bool get isDead => _dead;

  Enemy(this.enemyData) {
    animation = SpriteAnimation.fromFrameData(
      enemyData.image,
      SpriteAnimationData.sequenced(
        amount: enemyData.nFrames,
        stepTime: enemyData.stepTime,
        textureSize: enemyData.textureSize,
      ),
    );
  }

  /// Stomp from above: +[stompScore], play die animation, then remove.
  void stomp() {
    if (_dead || !enemyData.stompable || enemyData.dieImage == null) return;
    _dead = true;
    game.playerData.currentScore += enemyData.stompScore;
    removeOnFinish = true;
    final dieTs = enemyData.dieTextureSize ?? enemyData.textureSize;
    final runTs = enemyData.textureSize;
    // [Anchor.bottomLeft]: keep visual center when run vs die cell width differs.
    if (runTs.x != dieTs.x) {
      position.x +=
          (runTs.x - dieTs.x) * 0.5 * 0.6 * enemyData.visualScale;
    }
    size = dieTs * 0.6 * enemyData.visualScale;
    animation = SpriteAnimation.fromFrameData(
      enemyData.dieImage!,
      SpriteAnimationData.sequenced(
        amount: enemyData.dieNFrames,
        stepTime: enemyData.dieStepTime,
        textureSize: dieTs,
        texturePosition: enemyData.dieTexturePosition,
        loop: false,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final nudges = enemyData.dieDrawNudgeXTexture;
    if (_dead && nudges != null && nudges.isNotEmpty) {
      final i = (animationTicker?.currentIndex ?? 0).clamp(0, nudges.length - 1);
      final dieTs = enemyData.dieTextureSize ?? enemyData.textureSize;
      final t = nudges[i];
      final scaleX = size.x / dieTs.x;
      canvas.save();
      canvas.translate(t * scaleX, 0);
      super.render(canvas);
      canvas.restore();
      return;
    }
    super.render(canvas);
  }

  @override
  void onMount() {
    // Reduce the size of enemy as they look too
    // big compared to the dino.
    size *= 0.6 * enemyData.visualScale;

    // Add a hitbox for this enemy.
    final flyNonStomp =
        enemyData.canFly && !enemyData.stompable;
    add(
      RectangleHitbox.relative(
        flyNonStomp ? Vector2(0.62, 0.52) : Vector2.all(0.8),
        parentSize: size,
        position: flyNonStomp
            ? Vector2(size.x * 0.38, size.y * 0.48) / 2
            : Vector2(size.x * 0.2, size.y * 0.2) / 2,
      ),
    );
    super.onMount();
  }

  @override
  void update(double dt) {
    final m = game.runSpeedMultiplier;
    position.x -= enemyData.speedX * m * dt;

    // Remove the enemy and increase player score
    // by 1, if enemy has gone past left end of the screen.
    if (position.x < -enemyData.textureSize.x) {
      removeFromParent();
      if (!_dead) {
        game.playerData.currentScore += 1;
      }
    }

    // Match leg/wing cycle to scroll speed so slower base speeds don't look "stuck".
    super.update(dt * m);
  }
}
