import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class AccelerationBar extends StatelessWidget {
  const AccelerationBar({
    super.key,
    required this.value,
    required this.theme,
  });

  final double value;
  final HudTheme theme;

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 6.0).clamp(-1.0, 1.0);
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ACCEL / BRAKE',
            style: TextStyle(
              color: theme.secondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 10,
            child: CustomPaint(
              painter: _AccelerationPainter(
                value: normalized,
                theme: theme,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccelerationPainter extends CustomPainter {
  const _AccelerationPainter({required this.value, required this.theme});
  final double value;
  final HudTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final base = Paint()
      ..color = theme.secondary.withValues(alpha: .18)
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      base,
    );

    final active = Paint()
      ..color = theme.accent
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final x = centerX + value * centerX;
    canvas.drawLine(
      Offset(centerX, size.height / 2),
      Offset(x, size.height / 2),
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _AccelerationPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.theme != theme;
}
