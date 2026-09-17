import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class HudBackground extends StatelessWidget {
  const HudBackground({super.key, required this.theme});
  final HudTheme theme;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(theme),
      child: const SizedBox.expand(),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter(this.theme);
  final HudTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.background);

    switch (theme.backgroundStyle) {
      case HudBackgroundStyle.solid:
        return;
      case HudBackgroundStyle.carbon:
        _carbon(canvas, size);
      case HudBackgroundStyle.grid:
        _grid(canvas, size);
      case HudBackgroundStyle.road:
        _road(canvas, size);
      case HudBackgroundStyle.night:
        _night(canvas, size);
    }
  }

  void _carbon(Canvas canvas, Size size) {
    final p = Paint()..color = theme.secondary.withValues(alpha: .08);
    const d = 28.0;
    for (double x = -size.height; x < size.width; x += d) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, d / 2, size.height),
        p,
      );
    }
  }

  void _grid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = theme.secondary.withValues(alpha: .12)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _road(Canvas canvas, Size size) {
    final center = size.width / 2;
    final road = Path()
      ..moveTo(center - size.width * .08, size.height)
      ..lineTo(center - size.width * .012, size.height * .45)
      ..lineTo(center + size.width * .012, size.height * .45)
      ..lineTo(center + size.width * .08, size.height)
      ..close();
    canvas.drawPath(
      road,
      Paint()..color = theme.secondary.withValues(alpha: .10),
    );

    final line = Paint()
      ..color = theme.accent.withValues(alpha: .16)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(center, size.height),
      Offset(center, size.height * .48),
      line,
    );
  }

  void _night(Canvas canvas, Size size) {
    final p = Paint()..color = theme.secondary.withValues(alpha: .25);
    final random = math.Random(7);
    for (var i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * .7;
      canvas.drawCircle(Offset(x, y), random.nextDouble() * 1.4 + .3, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
