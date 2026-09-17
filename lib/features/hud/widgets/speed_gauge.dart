import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key, required this.speed, required this.maxSpeed, required this.style, required this.theme});
  final double speed, maxSpeed;
  final HudGaugeStyle style;
  final HudTheme theme;
  @override Widget build(BuildContext context) {
    switch (style) {
      case HudGaugeStyle.digital: return Column(mainAxisSize: MainAxisSize.min, children: [Text(speed.toStringAsFixed(0), style: TextStyle(color: theme.accent, fontSize: 132, fontWeight: FontWeight.w800, height: .82)), Text('km/h', style: TextStyle(color: theme.secondary, fontSize: 22))]);
      case HudGaugeStyle.linear:
        final v=(speed/maxSpeed).clamp(0.0,1.0);
        return Column(mainAxisSize: MainAxisSize.min, children: [Text('${speed.toStringAsFixed(0)} km/h', style: TextStyle(color: theme.accent,fontSize:48,fontWeight:FontWeight.w800)), const SizedBox(height:16), SizedBox(width:520, child:LinearProgressIndicator(value:v,minHeight:12,backgroundColor:theme.secondary.withValues(alpha:.22),color:theme.accent))]);
      case HudGaugeStyle.circular:
        final v=(speed/maxSpeed).clamp(0.0,1.0);
        return SizedBox(width:260,height:260,child:CustomPaint(painter:_GaugePainter(value:v,theme:theme),child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:64,fontWeight:FontWeight.w800)),Text('km/h',style:TextStyle(color:theme.secondary))]))));
    }
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.value,required this.theme});
  final double value; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final center=size.center(Offset.zero), radius=size.shortestSide/2-14, rect=Rect.fromCircle(center:center,radius:radius);
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=14..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.22);
    final active=Paint()..style=PaintingStyle.stroke..strokeWidth=14..strokeCap=StrokeCap.round..color=theme.accent;
    canvas.drawArc(rect,math.pi*.75,math.pi*1.5,false,base); canvas.drawArc(rect,math.pi*.75,math.pi*1.5*value,false,active);
  }
  @override bool shouldRepaint(covariant _GaugePainter old)=>old.value!=value||old.theme!=theme;
}