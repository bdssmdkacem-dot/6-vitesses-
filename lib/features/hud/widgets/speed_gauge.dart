import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key,required this.speed,required this.maxSpeed,required this.style,required this.theme,this.unitLabel='km/h',this.animate=true});
  final double speed,maxSpeed; final HudGaugeStyle style; final HudTheme theme; final String unitLabel; final bool animate;
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,constraints)=>TweenAnimationBuilder<double>(
    tween:Tween(begin:speed,end:speed),duration:animate?const Duration(milliseconds:260):Duration.zero,curve:Curves.easeOutCubic,
    builder:(context,value,_)=>switch(style){
      HudGaugeStyle.digital=>_DigitalSpeed(speed:value,theme:theme,unitLabel:unitLabel),
      HudGaugeStyle.digitalGt=>_DigitalGtSpeed(speed:value,theme:theme,unitLabel:unitLabel,maxWidth:constraints.maxWidth),
      HudGaugeStyle.linear=>_LinearSpeed(speed:value,maxSpeed:maxSpeed,theme:theme,unitLabel:unitLabel,animate:animate,maxWidth:constraints.maxWidth),
      HudGaugeStyle.circular=>_CircularSpeed(speed:value,maxSpeed:maxSpeed,theme:theme,unitLabel:unitLabel,animate:animate,maxWidth:constraints.maxWidth),
    }));
}
class _DigitalGtSpeed extends StatelessWidget {
  const _DigitalGtSpeed({required this.speed,required this.theme,required this.unitLabel,required this.maxWidth});
  final double speed,maxWidth; final HudTheme theme; final String unitLabel;
  @override Widget build(BuildContext context){
    final width=math.min(430.0,maxWidth*.52);
    final fontSize=math.min(126.0,math.max(82.0,width*.30));
    return SizedBox(width:width,child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text('6 VITESSES GT',style:TextStyle(color:theme.secondary.withValues(alpha:.78),fontSize:10,fontWeight:FontWeight.w800,letterSpacing:4)),
      const SizedBox(height:5),
      Stack(alignment:Alignment.center,children:[
        SizedBox(height:fontSize*.88,width:width,child:CustomPaint(painter:_DigitalGtArcPainter(progress:(speed/240.0).clamp(0.0,1.0).toDouble(),theme:theme))),
        Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:fontSize,fontWeight:FontWeight.w900,height:.86,letterSpacing:-3,shadows:theme.glow?[Shadow(color:theme.accent.withValues(alpha:.45),blurRadius:18)]:const[])),
      ]),
      const SizedBox(height:7),
      Text(unitLabel.toUpperCase(),style:TextStyle(color:theme.secondary,fontSize:13,fontWeight:FontWeight.w800,letterSpacing:2.5)),
    ]));
  }
}
class _DigitalGtArcPainter extends CustomPainter {
  const _DigitalGtArcPainter({required this.progress,required this.theme}); final double progress; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height*.92); final radius=math.min(size.width*.39,size.height*1.45); final rect=Rect.fromCircle(center:center,radius:radius);
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=3..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.14);
    final active=Paint()..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round..color=theme.accent.withValues(alpha:.8);
    canvas.drawArc(rect,math.pi*1.15,math.pi*.70,false,base); canvas.drawArc(rect,math.pi*1.15,math.pi*.70*progress,false,active);
  }
  @override bool shouldRepaint(covariant _DigitalGtArcPainter old)=>old.progress!=progress||old.theme!=theme;
}
class _DigitalSpeed extends StatelessWidget {
  const _DigitalSpeed({required this.speed,required this.theme,required this.unitLabel});
  final double speed; final HudTheme theme; final String unitLabel;
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:132,fontWeight:FontWeight.w800,height:.82,shadows:theme.glow?[Shadow(color:theme.accent.withValues(alpha:.5),blurRadius:18)]:const[])),
    Text(unitLabel,style:TextStyle(color:theme.secondary,fontSize:22,letterSpacing:2)),
  ]);
}
class _LinearSpeed extends StatelessWidget {
  const _LinearSpeed({required this.speed,required this.maxSpeed,required this.theme,required this.unitLabel,required this.animate,required this.maxWidth});
  final double speed,maxSpeed; final HudTheme theme; final String unitLabel; final bool animate; final double maxWidth;
  @override Widget build(BuildContext context){final double v=(speed/maxSpeed).clamp(0.0,1.0).toDouble();final width=math.min(520.0,maxWidth*.42);return Column(mainAxisSize:MainAxisSize.min,children:[
    Text('${speed.toStringAsFixed(0)} $unitLabel',style:TextStyle(color:theme.accent,fontSize:48,fontWeight:FontWeight.w800)),
    const SizedBox(height:16),SizedBox(width:width,child:TweenAnimationBuilder<double>(tween:Tween(begin:0,end:v),duration:animate?const Duration(milliseconds:300):Duration.zero,curve:Curves.easeOutCubic,builder:(_,value,__)=>
      LinearProgressIndicator(value:value,minHeight:12,backgroundColor:theme.secondary.withValues(alpha:.22),color:theme.accent))),
  ]);}
}
class _CircularSpeed extends StatelessWidget {
  const _CircularSpeed({
    required this.speed,
    required this.maxSpeed,
    required this.theme,
    required this.unitLabel,
    required this.animate,
    required this.maxWidth,
  });

  final double speed;
  final double maxSpeed;
  final HudTheme theme;
  final String unitLabel;
  final bool animate;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final double v = (speed / maxSpeed).clamp(0.0, 1.0).toDouble();
    final diameter = math.min(290.0, maxWidth * .27);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: v),
        duration: animate ? const Duration(milliseconds: 320) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (_, value, __) {
          return CustomPaint(
            painter: _GaugePainter(value: value, theme: theme),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speed.toStringAsFixed(0),
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 68,
                      fontWeight: FontWeight.w800,
                      shadows: theme.glow
                          ? [Shadow(color: theme.accent.withValues(alpha: .45), blurRadius: 14)]
                          : const [],
                    ),
                  ),
                  Text(
                    unitLabel,
                    style: TextStyle(color: theme.secondary, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
class _GaugePainter extends CustomPainter {

  const _GaugePainter({required this.value,required this.theme}); final double value; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final center=size.center(Offset.zero),radius=size.shortestSide/2-18,rect=Rect.fromCircle(center:center,radius:radius);
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=15..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.18);
    final active=Paint()..style=PaintingStyle.stroke..strokeWidth=15..strokeCap=StrokeCap.round..color=theme.accent;
    canvas.drawArc(rect,math.pi*.75,math.pi*1.5,false,base);canvas.drawArc(rect,math.pi*.75,math.pi*1.5*value,false,active);
    final tick=Paint()..color=theme.secondary.withValues(alpha:.35)..strokeWidth=2;
    for(var i=0;i<=12;i++){final angle=math.pi*.75+math.pi*1.5*i/12;final a=Offset(center.dx+math.cos(angle)*(radius-4),center.dy+math.sin(angle)*(radius-4));final b=Offset(center.dx+math.cos(angle)*(radius-14),center.dy+math.sin(angle)*(radius-14));canvas.drawLine(a,b,tick);}
  }
  @override bool shouldRepaint(covariant _GaugePainter o)=>o.value!=value||o.theme!=theme;
}
