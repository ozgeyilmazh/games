import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../cat_sprites.dart';
import '../cat_stack_game.dart';
import '../game_config.dart';
import '../game_state.dart';
import 'rope_line.dart';

/// İp ekranın üstünde sabit; kedi yatay sallanır (Wood Stack tarzı).
class SwingingCat extends Component with HasGameReference<CatStackGame> {
  SwingingCat({required this.spriteIndex, required this.score});

  final int spriteIndex;
  final int score;

  late final CatSpriteInfo _catInfo;
  late final SpriteComponent _sprite;
  late final RopeLine _rope;
  double _time = 0;

  double get _omega => GameConfig.swingOmegaForScore(score);

  Vector2 get _anchor => game.ropeAnchor;

  /// İp ucunun bağlandığı nokta — kedinin üst ortası.
  Vector2 get ropeHook {
    final ropeLen = game.ropeLengthWorld;
    final swing = game.swingHorizontalFor(_catInfo);
    return _anchor +
        Vector2(
          swing * math.sin(_omega * _time),
          ropeLen,
        );
  }

  /// Fizik gövde merkezi.
  Vector2 get bodyCenter => ropeHook + _catInfo.hookToBodyCenter;

  Vector2 get releaseVelocity {
    final swing = game.swingHorizontalFor(_catInfo);
    final angleVel = _omega * swing * math.cos(_omega * _time);
    return Vector2(
      angleVel * GameConfig.releaseVelocityScaleForScore(score),
      0,
    );
  }

  @override
  Future<void> onLoad() async {
    _catInfo = CatSprites.infoForIndex(spriteIndex);
    _rope = RopeLine(anchor: _anchor, end: ropeHook);
    _sprite = SpriteComponent(
      sprite: _catInfo.displaySprite,
      size: _catInfo.contentWorldSize,
      anchor: Anchor.center,
    );
    add(_rope);
    add(_sprite);
  }

  bool get _isVisible =>
      game.phase == CatStackPhase.ready ||
      game.phase == CatStackPhase.swinging;

  @override
  void update(double dt) {
    if (!_isVisible) {
      removeFromParent();
      return;
    }
    super.update(dt);
    _time += dt;
    final center = bodyCenter;
    _sprite.position = center + _catInfo.contentCenterOffsetWorld;
    _rope
      ..anchor = _anchor
      ..end = center + Vector2(0, _catInfo.ropeHookOffsetY);
  }

  @override
  void renderTree(Canvas canvas) {
    if (!_isVisible) return;
    super.renderTree(canvas);
  }

  void release() {
    if (game.phase != CatStackPhase.swinging) return;
    final vel = releaseVelocity;
    // Düşme pozu: yatay hıza göre hafif eğim.
    final fallAngle = (vel.x * 0.09).clamp(-0.38, 0.38);
    game.onCatReleased(
      position: bodyCenter,
      angle: fallAngle,
      linearVelocity: vel,
      spriteIndex: spriteIndex,
    );
  }
}
