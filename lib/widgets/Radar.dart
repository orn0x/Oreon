import 'package:flutter/material.dart';

class RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isScanning;

  RadarPainter(this.animation, this.isScanning) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 6;

    final ringPaint = Paint()
      ..color = Colors.tealAccent.withValues(alpha: isScanning ? 0.18 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawCircle(center, maxRadius * 0.3, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.6, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.9, ringPaint);

    if (!isScanning) return;

    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.tealAccent.withValues(alpha: 0.55), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: maxRadius),
        -1.57 + (animation.value * 6.28),
        1.4,
        false,
      )
      ..close();

    canvas.drawPath(sweepPath, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) =>
      isScanning != oldDelegate.isScanning || animation.value != oldDelegate.animation.value;
}

class _StaticBackgroundGlow extends StatelessWidget {
  const _StaticBackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -180,
      left: -180,
      child: IgnorePointer(
        child: Container(
          width: 560,
          height: 560,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.teal.withValues(alpha: 0.09), Colors.transparent],
              stops: const [0.0, 0.7],
            ),
          ),
        ),
      ),
    );
  }
}