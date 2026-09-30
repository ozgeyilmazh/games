import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '/game/enemy.dart';
import '/game/plant_enemy.dart';
import '/game/dino_run.dart';
import '/game/audio_manager.dart';
import '/models/player_data.dart';

/// This enum represents the animation states of [Dino].
enum DinoAnimationStates { idle, run, kick, hit, sprint }

// This represents the dino character of this game.
class Dino extends SpriteAnimationGroupComponent<DinoAnimationStates>
    with CollisionCallbacks, HasGameReference<DinoRun> {
  // A map of all the animation states and their corresponding animations.
  static final _animationMap = {
    DinoAnimationStates.idle: SpriteAnimationData.sequenced(
      amount: 4,
      stepTime: 0.1,
      textureSize: Vector2.all(24),
    ),
    DinoAnimationStates.run: SpriteAnimationData.sequenced(
      amount: 6,
      stepTime: 0.085,
      textureSize: Vector2.all(24),
      texturePosition: Vector2((4) * 24, 0),
    ),
    DinoAnimationStates.kick: SpriteAnimationData.sequenced(
      amount: 4,
      stepTime: 0.1,
      textureSize: Vector2.all(24),
      texturePosition: Vector2((4 + 6) * 24, 0),
    ),
    DinoAnimationStates.hit: SpriteAnimationData.sequenced(
      amount: 3,
      stepTime: 0.1,
      textureSize: Vector2.all(24),
      texturePosition: Vector2((4 + 6 + 4) * 24, 0),
    ),
    DinoAnimationStates.sprint: SpriteAnimationData.sequenced(
      amount: 7,
      stepTime: 0.1,
      textureSize: Vector2.all(24),
      texturePosition: Vector2((4 + 6 + 4 + 3) * 24, 0),
    ),
  };

  // The max distance from top of the screen beyond which
  // dino should never go. Basically the screen height - ground height
  double yMax = 0.0;

  // Dino's current speed along y-axis.
  double speedY = 0.0;

  // Controlls how long the hit animations will be played.
  final Timer _hitTimer = Timer(1);

  static const double gravity = 800;

  /// Uses [DinoRun.characterMovementMultiplier] (world speed + extra character boost).
  static const double _minokiTimeScale = 1.55;

  final PlayerData playerData;

  bool isHit = false;
  double _invincibleTimeLeft = 0;

  bool get isInvincible => _invincibleTimeLeft > 0;

  Dino(Image image, this.playerData)
      : super.fromFrameData(image, _animationMap);

  @override
  void onMount() {
    // First reset all the important properties, because onMount()
    // will be called even while restarting the game.
    _reset();

    // Add a hitbox for dino.
    add(
      RectangleHitbox.relative(
        Vector2(0.5, 0.7),
        parentSize: size,
        position: Vector2(size.x * 0.5, size.y * 0.3) / 2,
      ),
    );
    yMax = y;

    /// Set the callback for [_hitTimer].
    _hitTimer.onTick = () {
      current = DinoAnimationStates.run;
      isHit = false;
    };

    super.onMount();
  }

  @override
  void update(double dt) {
    final m = game.characterMovementMultiplier;
    final s = dt * _minokiTimeScale * m;
    // v = u + at
    speedY += gravity * s;

    // d = s0 + s * t
    y += speedY * s;

    /// This code makes sure that dino never goes beyond [yMax].
    if (isOnGround) {
      y = yMax;
      speedY = 0.0;
      if ((current != DinoAnimationStates.hit) &&
          (current != DinoAnimationStates.run)) {
        current = DinoAnimationStates.run;
      }
    }

    _hitTimer.update(dt);
    if (_invincibleTimeLeft > 0) {
      _invincibleTimeLeft -= dt;
    }
    super.update(s);
  }

  // Gets called when dino collides with other Collidables.
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Enemy) {
      if (other.isDead) {
        super.onCollision(intersectionPoints, other);
        return;
      }
      if (other.enemyData.stompable && _isStompingStompable(other)) {
        other.stomp();
        // Small bounce like landing on a bump.
        speedY = -200;
        super.onCollision(intersectionPoints, other);
        return;
      }
      if (other.enemyData.canFly &&
          !other.enemyData.stompable &&
          _isJumpingOverFlyer(other)) {
        super.onCollision(intersectionPoints, other);
        return;
      }
      if (!isHit && !isInvincible) {
        hit();
      }
    } else if (other is PlantEnemy) {
      if (other.isDead) {
        super.onCollision(intersectionPoints, other);
        return;
      }
      if (_isStompingPlant(other)) {
        other.stomp();
        speedY = -200;
        super.onCollision(intersectionPoints, other);
        return;
      }
      if (!isHit && !isInvincible) {
        hit();
      }
    }
    super.onCollision(intersectionPoints, other);
  }

  /// Non-stomp flyers (e.g. Bat): no hurt if feet are above their mid-body (jump-over).
  bool _isJumpingOverFlyer(Enemy e) {
    final feetY = position.y;
    final midY = e.position.y - e.size.y * 0.38;
    const grace = 12.0;
    return feetY < midY + grace;
  }

  /// Stompable ground enemies (e.g. Mushroom): feet in the upper body while falling.
  /// Same-ground side bumps put feet at the bottom → not a stomp.
  bool _isStompingStompable(Enemy enemy) {
    final feetY = position.y;
    final topY = enemy.position.y - enemy.size.y;
    final notRising = speedY > -30;

    // Stomp flying stompable (Daemon): feet above mid-body, not rising up through it.
    if (enemy.enemyData.canFly) {
      final midY = enemy.position.y - enemy.size.y * 0.45;
      return notRising && feetY < midY;
    }

    // Ground stompable: feet must land in the upper ~65% (excludes side run at ground level).
    final maxFeetY = topY + enemy.size.y * 0.65;
    return notRising && feetY <= maxFeetY;
  }

  /// [PlantEnemy] keeps unscaled [size] but uses [scale]; stomp zone uses real height.
  bool _isStompingPlant(PlantEnemy plant) {
    if (plant.isDead) return false;
    final h = plant.size.y * plant.scale.y;
    final topY = plant.position.y - h;
    final feetY = position.y;
    final maxFeetY = topY + h * 0.65;
    return speedY > -30 && feetY <= maxFeetY;
  }

  // Returns true if dino is on ground.
  bool get isOnGround => (y >= yMax);

  // Makes the dino jump.
  void jump() {
    // Jump only if dino is on ground.
    if (isOnGround) {
      speedY = -292;
      current = DinoAnimationStates.idle;
      AudioManager.instance.playSfx('jump14.wav');
    }
  }

  // This method changes the animation state to
  /// [DinoAnimationStates.hit], plays the hit sound
  /// effect and reduces the player life by 1.
  void hit() {
    if (isInvincible) {
      return;
    }
    isHit = true;
    AudioManager.instance.playSfx('hurt7.wav');
    current = DinoAnimationStates.hit;
    _hitTimer.start();
    playerData.lives -= 1;
  }

  void revive() {
    isHit = false;
    _hitTimer.stop();
    _invincibleTimeLeft = 1.5;
    current = DinoAnimationStates.run;
  }

  // This method reset some of the important properties
  // of this component back to normal.
  void _reset() {
    if (isMounted) {
      removeFromParent();
    }
    anchor = Anchor.bottomLeft;
    position = Vector2(32, game.virtualSize.y - 22);
    size = Vector2.all(24);
    current = DinoAnimationStates.run;
    isHit = false;
    speedY = 0.0;
    _invincibleTimeLeft = 0;
  }
}
