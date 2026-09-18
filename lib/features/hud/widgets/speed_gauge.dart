import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key,required this.speed,required this.maxSpeed,required this.style,required this.theme,this.unitLabel='km/h',this.animate=true});
  final double speed,maxSpeed; final HudGaugeStyle style; final HudTheme theme; final String unitLabel; final bool animate;

  @override
  Widget build(BuildContext context)=>TweenAnimationBuilder<double>(
    tween:Tween(end:speed),duration:animate?const Duration(milliseconds:180):Duration.zero,curve:Curves.easeOutCubic,
    builder:(context,value,_)=>switch(style){
      HudGaugeStyle.digital=>_DigitalSpeed(speed:value,maxSpeed:maxSpeed,theme:theme,unitLabel:unitLabel),
      HudGaugeStyle.linear=>_LinearSpeed(speed:value,maxSpeed:maxSpeed,theme:theme,unitLabel:unitLabel),
      HudGaugeStyle.circular=>_CircularSpeed(speed:value,maxSpeed:maxSpeed,theme:theme,unitLabel:unitLabel),
    });
}

class _DigitalSpeed extends StatelessWidget {
  const _DigitalSpeed({required this.speed,required this.maxSpeed,required this.theme,required this.unitLabel});
  final double speed,maxSpeed; final HudTheme theme; final String unitLabel;
  @override Widget build(BuildContext context){
    final double ratio=maxSpeed<=0?0.0:(speed/maxSpeed).clamp(0.0,1.0).toDouble();
    return Column(mainAxisSize:MainAxisSize.min,children:[
      Row(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.end,children:[
        Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:132,fontWeight:FontWeight.w900,height:.78,letterSpacing:-4,shadows:theme.glow?[Shadow(color:theme.accent.withValues(alpha:.45),blurRadius:20)]:const[])),
        Padding(padding:const EdgeInsets.only(bottom:10,left:10),child:Text(unitLabel,style:TextStyle(color:theme.secondary,fontSize:18,fontWeight:FontWeight.w700,letterSpacing:1.5))),
      ]),
      const SizedBox(height:18),
      SizedBox(width:360,height:5,child:ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:ratio,backgroundColor:theme.secondary.withValues(alpha:.14),color:theme.accent))),
    ]);
  }
}

class _LinearSpeed extends StatelessWidget {
  const _LinearSpeed({required this.speed,required this.maxSpeed,required this.theme,required this.unitLabel});
  final double speed,maxSpeed; final HudTheme theme; final String unitLabel;
  @override Widget build(BuildContext context){
    final ratio=maxSpeed<=0?0:(speed/maxSpeed).clamp(0.0,1.0);
    return SizedBox(width:620,child:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
        Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:78,fontWeight:FontWeight.w900,height:.85)),
        Padding(padding:const EdgeInsets.only(bottom:7,left:8),child:Text(unitLabel,style:TextStyle(color:theme.secondary,fontSize:17,fontWeight:FontWeight.w700))),
      ]),
      const SizedBox(height:12),
      CustomPaint(size:const Size(600,46),painter:_LinearScalePainter(value:ratio,theme:theme)),
    ]));
  }
}

class _LinearScalePainter extends CustomPainter {
  const _LinearScalePainter({required this.value,required this.theme});
  final double value; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final left=12.0,right=size.width-12, y=30.0;
    final base=Paint()..color=theme.secondary.withValues(alpha:.18)..strokeWidth=6..strokeCap=StrokeCap.round;
    final active=Paint()..color=theme.accent..strokeWidth=6..strokeCap=StrokeCap.round;
    canvas.drawLine(Offset(left,y),Offset(right,y),base);
    canvas.drawLine(Offset(left,y),Offset(left+(right-left)*value,y),active);
    final ticks=Paint()..color=theme.secondary.withValues(alpha:.42)..strokeWidth=1.5;
    for(var i=0;i<=20;i++){
      final x=left+(right-left)*i/20;
      final h=i%5==0?15.0:8.0;
      canvas.drawLine(Offset(x,y-h),Offset(x,y+2),ticks);
    }
    final markerX=left+(right-left)*value;
    final marker=Paint()..color=theme.accent;
    canvas.drawCircle(Offset(markerX,y),7,marker);
    final tp=TextPainter(text:TextSpan(text:'0',style:TextStyle(color:theme.secondary,fontSize:10)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(left-tp.width/2,0));
    final end=TextPainter(text:TextSpan(text:'MAX',style:TextStyle(color:theme.secondary,fontSize:10)),textDirection:TextDirection.ltr)..layout();
    end.paint(canvas,Offset(right-end.width/2,0));
  }
  @override bool shouldRepaint(covariant _LinearScalePainter old)=>old.value!=value||old.theme!=theme;
}

class _CircularSpeed extends StatelessWidget {
  const _CircularSpeed({required this.speed,required this.maxSpeed,required this.theme,required this.unitLabel});
  final double speed,maxSpeed; final HudTheme theme; final String unitLabel;
  @override Widget build(BuildContext context){
    final ratio=maxSpeed<=0?0:(speed/maxSpeed).clamp(0.0,1.0);
    return SizedBox(width:330,height:330,child:TweenAnimationBuilder<double>(
      tween:Tween(end:ratio),duration:const Duration(milliseconds:180),curve:Curves.easeOutCubic,
      builder:(_,value,__){
        return CustomPaint(painter:_CircularGaugePainter(value:value,theme:theme,maxSpeed:maxSpeed),
          child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
            Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:70,fontWeight:FontWeight.w900,height:.9,shadows:theme.glow?[Shadow(color:theme.accent.withValues(alpha:.4),blurRadius:14)]:const[])),
            Text(unitLabel,style:TextStyle(color:theme.secondary,fontSize:15,fontWeight:FontWeight.w700,letterSpacing:1.5)),
          ])));
      },
    ));
  }
}

class _CircularGaugePainter extends CustomPainter {
  const _CircularGaugePainter({required this.value,required this.theme,required this.maxSpeed});
  final double value,maxSpeed; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final center=size.center(Offset.zero),radius=size.shortestSide/2-24,rect=Rect.fromCircle(center:center,radius:radius);
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=14..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.14);
    canvas.drawArc(rect,math.pi*.72,math.pi*1.56,false,base);
    final start=math.pi*.72;
    final active=Paint()..style=PaintingStyle.stroke..strokeWidth=14..strokeCap=StrokeCap.round..color=theme.accent;
    canvas.drawArc(rect,start,math.pi*1.56*value,false,active);

    for(var i=0;i<=24;i++){
      final a=start+math.pi*1.56*i/24;
      final major=i%4==0;
      final outer=Offset(center.dx+math.cos(a)*(radius+2),center.dy+math.sin(a)*(radius+2));
      final inner=Offset(center.dx+math.cos(a)*(radius-(major?17:10)),center.dy+math.sin(a)*(radius-(major?17:10)));
      final p=Paint()..color=theme.secondary.withValues(alpha:major?.65:.32)..strokeWidth=major?2.4:1.3;
      canvas.drawLine(inner,outer,p);
      if(major&&i<24){
        final labelValue=(maxSpeed*i/24).round();
        final pos=Offset(center.dx+math.cos(a)*(radius-35),center.dy+math.sin(a)*(radius-35));
        final tp=TextPainter(text:TextSpan(text:'$labelValue',style:TextStyle(color:theme.secondary.withValues(alpha:.75),fontSize:9,fontWeight:FontWeight.w700)),textDirection:TextDirection.ltr)..layout();
        tp.paint(canvas,Offset(pos.dx-tp.width/2,pos.dy-tp.height/2));
      }
    }

    final zoneStart=.75,zoneEnd=.90;
    final zone=Paint()..style=PaintingStyle.stroke..strokeWidth=14..color=theme.accent.withValues(alpha:.16);
    canvas.drawArc(rect,start+math.pi*1.56*zoneStart,math.pi*1.56*(zoneEnd-zoneStart),false,zone);

    final needleAngle=start+math.pi*1.56*value;
    final needle=Paint()..color=theme.accent..strokeWidth=3..strokeCap=StrokeCap.round;
    final tip=Offset(center.dx+math.cos(needleAngle)*(radius-8),center.dy+math.sin(needleAngle)*(radius-8));
    canvas.drawLine(center,tip,needle);
    canvas.drawCircle(center,6,Paint()..color=theme.accent);
  }
  @override bool shouldRepaint(covariant _CircularGaugePainter old)=>old.value!=value||old.theme!=theme||old.maxSpeed!=maxSpeed;
}
