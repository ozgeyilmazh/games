import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';

class RopeLine extends Component {
  RopeLine({required this.anchor, required this.end});

  Vector2 anchor;
  Vector2 end;

  @override
  void render(Canvas canvas) {
    _drawBranch(canvas, anchor);
    canvas.drawLine(
      anchor.toOffset(),
      end.toOffset(),
      Paint()
        ..color = const Color(0xFF8D6E63)
        ..strokeWidth = 0.14
        ..strokeCap = StrokeCap.round,
    );
  }

  /// İpin üst ucu bir ağaç dalına bağlıymış gibi.
  void _drawBranch(Canvas canvas, Vector2 at) {
    final origin = at.toOffset();
    final trunk = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 0.22
      ..strokeCap = StrokeCap.round;
    final bark = Paint()
      ..color = const Color(0xFF795548)
      ..strokeWidth = 0.12
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      origin + const Offset(-0.85, -0.08),
      origin + const Offset(0.95, 0.06),
      trunk,
    );
    canvas.drawLine(
      origin + const Offset(0.15, 0.02),
      origin + const Offset(0.55, -0.35),
      bark,
    );
    canvas.drawLine(
      origin + const Offset(-0.35, -0.02),
      origin + const Offset(-0.7, -0.28),
      bark,
    );

    final leaf = Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.85);
    for (final p in [
      origin + const Offset(0.55, -0.42),
      origin + const Offset(0.72, -0.28),
      origin + const Offset(-0.72, -0.34),
      origin + const Offset(-0.55, -0.18),
    ]) {
      canvas.drawCircle(p, 0.16 + 0.04 * math.sin(p.dx * 8), leaf);
    }
  }
}
