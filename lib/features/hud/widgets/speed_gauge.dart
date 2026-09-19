import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key, required this.speed, required this.maxSpeed, required this.style, required this.theme, this.unitLabel = 'km/h', this.animate = true});
  final double speed, maxSpeed;
  final HudGaugeStyle style;
  final HudTheme theme;
  final String unitLabel;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => TweenAnimationBuilder<double>(
        tween: Tween(begin: speed, end: speed),
        duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => switch (style) {
          HudGaugeStyle.digital => _DigitalSpeed(speed: value, theme: theme, unitLabel: unitLabel, maxWidth: constraints.maxWidth),
          HudGaugeStyle.linear => _LinearSpeed(speed: value, maxSpeed: maxSpeed, theme: theme, unitLabel: unitLabel, animate: animate, maxWidth: constraints.maxWidth),
          HudGaugeStyle.circular => _CircularSpeed(speed: value, maxSpeed: maxSpeed, theme: theme, unitLabel: unitLabel, animate: animate, maxWidth: constraints.maxWidth),
        },
      ),
    );
  }
}

class _DigitalSpeed extends StatelessWidget {
  const _DigitalSpeed({required this.speed, required this.theme, required this.unitLabel, required this.maxWidth});
  final double speed, maxWidth;
  final HudTheme theme;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final width = math.min(430.0, maxWidth * .52);
    final fontSize = math.min(126.0, math.max(82.0, width * .30));
    return SizedBox(
      width: width,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('6 VITESSES', style: TextStyle(color: theme.secondary.withValues(alpha: .78), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 4)),
        const SizedBox(height: 5),
        Stack(alignment: Alignment.center, children: [
          SizedBox(height: fontSize * .88, width: width, child: CustomPaint(
            painter: _DigitalArcPainter(progress: (speed / 240.0).clamp(0.0, 1.0).toDouble(), theme: theme),
          )),
          Text(speed.toStringAsFixed(0), style: TextStyle(
            color: theme.accent, fontSize: fontSize, fontWeight: FontWeight.w900, height: .86, letterSpacing: -3,
            shadows: theme.glow ? [Shadow(color: theme.accent.withValues(alpha: .45), blurRadius: 18)] : const [],
          )),
        ]),
        const SizedBox(height: 7),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 28, height: 2, color: theme.accent.withValues(alpha: .75)),
          const SizedBox(width: 9),
          Text(unitLabel.toUpperCase(), style: TextStyle(color: theme.secondary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
          const SizedBox(width: 9),
          Container(width: 28, height: 2, color: theme.accent.withValues(alpha: .75)),
        ]),
      ]),
    );
  }
}

class _DigitalArcPainter extends CustomPainter {
  const _DigitalArcPainter({required this.progress, required this.theme});
  final double progress;
  final HudTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .92);
    final radius = math.min(size.width * .39, size.height * 1.45);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = theme.secondary.withValues(alpha: .14);
    final active = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = theme.accent.withValues(alpha: .8);
    canvas.drawArc(rect, math.pi * 1.15, math.pi * .70, false, base);
    canvas.drawArc(rect, math.pi * 1.15, math.pi * .70 * progress, false, active);
    final tick = Paint()..color = theme.secondary.withValues(alpha: .30)..strokeWidth = 1.5;
    for (var i = 0; i <= 10; i++) {
      final angle = math.pi * 1.15 + math.pi * .70 * i / 10;
      final outer = Offset(center.dx + math.cos(angle) * (radius + 4), center.dy + math.sin(angle) * (radius + 4));
      final inner = Offset(center.dx + math.cos(angle) * (radius - 6), center.dy + math.sin(angle) * (radius - 6));
      canvas.drawLine(inner, outer, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _DigitalArcPainter old) => old.progress != progress || old.theme != theme;
}

class _LinearSpeed extends StatelessWidget {
  const _LinearSpeed({required this.speed, required this.maxSpeed, required this.theme, required this.unitLabel, required this.animate, required this.maxWidth});
  final double speed, maxSpeed, maxWidth;
  final HudTheme theme;
  final String unitLabel;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final v = (speed / maxSpeed).clamp(0.0, 1.0).toDouble();
    final width = math.min(520.0, maxWidth * .42);
    return SizedBox(width: width, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('6 VITESSES', style: TextStyle(color: theme.secondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 3)),
      const SizedBox(height: 5),
      Text('${{speed.toStringAsFixed(0)} $unitLabel', style: TextStyle(color: theme.accent, fontSize: 50, fontWeight: FontWeight.w900, letterSpacing: -1)),
      const SizedBox(height: 12),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: v),
        duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (_, value, __) => LinearProgressIndicator(value: value, minHeight: 9, backgroundColor: theme.secondary.withValues(alpha: .18), color: theme.accent),
      ),
    ]));
  }
}

class _CircularSpeed extends StatelessWidget {
  const _CircularSpeed({required this.speed, required this.maxSpeed, required this.theme, required this.unitLabel, required this.animate, required this.maxWidth});
  final double speed, maxSpeed, maxWidth;
  final HudTheme theme;
  final String unitLabel;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final diameter = math.min(290.0, maxWidth * .27);
    final v = (speed / maxSpeed).clamp(0.0, 1.0).toDouble();
    return SizedBox(width: diameter, height: diameter, child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: v),
      duration: animate ? const Duration(milliseconds: 320) : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => CustomPaint(
        painter: _GaugePainter(value: value, theme: theme),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('6 VITESSES', style: TextStyle(color: theme.secondary, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 2)),
          const SizedBox(height: 3),
          Text(speed.toStringAsFixed(0), style: TextStyle(color: theme.accent, fontSize: 66, fontWeight: FontWeight.w900, shadows: theme.glow ? [Shadow(color: theme.accent.withValues(alpha: .4), blurRadius: 14)] : const [])),
          Text(unitLabel, style: TextStyle(color: theme.secondary, fontSize: 12, letterSpacing: 1.5)),
        ])),
      ),
    ));
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.value, required this.theme});
  final double value;
  final HudTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round..color = theme.secondary.withValues(alpha: .16);
    final active = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round..color = theme.accent;
    canvas.drawArc(rect, math.pi * .75, math.pi * 1.5, false, base);
    canvas.drawArc(rect, math.pi * .75, math.pi * 1.5 * value, false, active);
    final tick = Paint()..color = theme.secondary.withValues(alpha: .32)..strokeWidth = 2;
    for (var i = 0; i <= 12; i++) {
      final angle = math.pi * .75 + math.pi * 1.5 * i / 12;
      final a = Offset(center.dx + math.cos(angle) * (radius - 4), center.dy + math.sin(angle) * (radius - 4));
      final b = Offset(center.dx + math.cos(angle) * (radius - 14), center.dy + math.sin(angle) * (radius - 14));
      canvas.drawLine(a, b, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.theme != theme;
}
