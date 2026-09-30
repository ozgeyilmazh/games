import 'package:flutter/material.dart';

/// Beyaz zemin + logo; üstünden hafif ışık bandı geçer.
class LogoShimmerSplash extends StatefulWidget {
  const LogoShimmerSplash({required this.onFinished, super.key});

  final VoidCallback onFinished;

  static const double logoSize = 180;

  @override
  State<LogoShimmerSplash> createState() => _LogoShimmerSplashState();
}

class _LogoShimmerSplashState extends State<LogoShimmerSplash>
    with SingleTickerProviderStateMixin {
  static const _asset = AssetImage('assets/images/logo.png');

  late final AnimationController _sweep;
  int _sweepCount = 0;

  static const _sweepsTotal = 2;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addStatusListener(_onSweepStatus);
    _sweep.forward();
  }

  void _onSweepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _sweepCount++;
    if (_sweepCount < _sweepsTotal) {
      _sweep.forward(from: 0);
    } else {
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: LogoShimmerSplash.logoSize,
          height: LogoShimmerSplash.logoSize,
          child: AnimatedBuilder(
            animation: _sweep,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  child!,
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ShineSweepPainter(progress: _sweep.value),
                    ),
                  ),
                ],
              );
            },
            child: Image(
              image: _asset,
              width: LogoShimmerSplash.logoSize,
              height: LogoShimmerSplash.logoSize,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShineSweepPainter extends CustomPainter {
  _ShineSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final bandCenter = size.width * (-0.35 + progress * 1.7);
    final rect = Rect.fromLTWH(
      bandCenter - size.width * 0.22,
      0,
      size.width * 0.44,
      size.height,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..blendMode = BlendMode.softLight;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShineSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
