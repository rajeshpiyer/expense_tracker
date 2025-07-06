import 'package:flutter/material.dart';

class FinanceFlowLogo extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool animated;

  const FinanceFlowLogo({
    super.key,
    this.size = 60,
    this.primaryColor,
    this.secondaryColor,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = primaryColor ?? const Color(0xFFFFD700);
    final secondary = secondaryColor ?? const Color(0xFFFFA500);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FinanceFlowLogoPainter(
          primaryColor: primary,
          secondaryColor: secondary,
          animated: animated,
        ),
      ),
    );
  }
}

class _FinanceFlowLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool animated;

  _FinanceFlowLogoPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.animated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF2D2D2D),
          const Color(0xFF1A1A1A),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.9, backgroundPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius * 0.85, ringPaint);

    // Main F shape
    final fPaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: center, width: size.width, height: size.height))
      ..style = PaintingStyle.fill;

    final fPath = Path();
    final fSize = radius * 0.6;
    final fLeft = center.dx - fSize * 0.4;
    final fTop = center.dy - fSize * 0.6;
    final fRight = center.dx + fSize * 0.3;
    final fBottom = center.dy + fSize * 0.6;

    // Create F shape
    fPath.moveTo(fLeft, fTop);
    fPath.lineTo(fLeft, fBottom);
    fPath.lineTo(fLeft + fSize * 0.15, fBottom);
    fPath.lineTo(fLeft + fSize * 0.15, center.dy + fSize * 0.1);
    fPath.lineTo(fRight - fSize * 0.2, center.dy + fSize * 0.1);
    fPath.lineTo(fRight - fSize * 0.2, center.dy - fSize * 0.1);
    fPath.lineTo(fLeft + fSize * 0.15, center.dy - fSize * 0.1);
    fPath.lineTo(fLeft + fSize * 0.15, fTop + fSize * 0.3);
    fPath.lineTo(fRight, fTop + fSize * 0.3);
    fPath.lineTo(fRight, fTop);
    fPath.close();

    canvas.drawPath(fPath, fPaint);

    // Flow lines
    final flowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Right flow lines
    final flowPath1 = Path();
    flowPath1.moveTo(fRight, center.dy - fSize * 0.3);
    flowPath1.quadraticBezierTo(
      center.dx + fSize * 0.6, center.dy - fSize * 0.3,
      center.dx + fSize * 0.8, center.dy - fSize * 0.1,
    );

    final flowPath2 = Path();
    flowPath2.moveTo(fRight, center.dy);
    flowPath2.quadraticBezierTo(
      center.dx + fSize * 0.7, center.dy,
      center.dx + fSize * 0.9, center.dy + fSize * 0.2,
    );

    final flowPath3 = Path();
    flowPath3.moveTo(fRight, center.dy + fSize * 0.3);
    flowPath3.quadraticBezierTo(
      center.dx + fSize * 0.6, center.dy + fSize * 0.3,
      center.dx + fSize * 0.8, center.dy + fSize * 0.5,
    );

    canvas.drawPath(flowPath1, flowPaint);
    canvas.drawPath(flowPath2, flowPaint..strokeWidth = 2);
    canvas.drawPath(flowPath3, flowPaint..strokeWidth = 3);

    // Flow particles
    final particlePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final particles = [
      Offset(center.dx + fSize * 0.5, center.dy - fSize * 0.2),
      Offset(center.dx + fSize * 0.7, center.dy - fSize * 0.05),
      Offset(center.dx + fSize * 0.6, center.dy + fSize * 0.15),
      Offset(center.dx + fSize * 0.8, center.dy + fSize * 0.35),
    ];

    for (int i = 0; i < particles.length; i++) {
      final particleSize = (i % 2 == 0) ? 2.0 : 1.5;
      canvas.drawCircle(particles[i], particleSize, particlePaint);
    }

    // Bottom accent line
    final accentPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - fSize * 0.4, fBottom + fSize * 0.1),
      Offset(center.dx + fSize * 0.4, fBottom + fSize * 0.1),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
