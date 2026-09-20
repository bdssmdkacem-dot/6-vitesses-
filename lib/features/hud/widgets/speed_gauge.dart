import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';
class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key,required this.speed,required this.maxSpeed,required this.style,required this.theme,this.unitLabel='km/h',this.animate=true,this.gtLayout=GtLayout.nav,this.gForce=0,this.longitudinalAccel=0,this.gear=0});
  final double speed,maxSpeed; final HudGaugeStyle style; final HudTheme theme; final String unitLabel; final bool animate; final GtLayout gtLayout; final double gForce,longitudinalAccel; final int gear;
  @override Widget build(BuildContext context)=>LayoutBuilder(builder:(context,constraints)=>TweenAnimationBuilder<double>(
    tween:Tween(begin:speed,end:speed),duration:animate?const Duration(milliseconds:260):Duration.zero,curve:Curves.easeOutCubic,
    builder:(context,value,_)=>switch(style){
      HudGaugeStyle.digital=>_DigitalSpeed(speed:value,theme:theme,unitLabel:unitLabel),
      HudGaugeStyle.digitalGt=>_DigitalGtSpeed(speed:value,theme:theme,unitLabel:unitLabel,maxWidth:constraints.maxWidth,layout:gtLayout,gForce:gForce,longitudinalAccel:longitudinalAccel,gear:gear),
      HudGaugeStyle.linear=>_LinearSpeed(speed:value,maxSpeed:maxSpeed,theme:theme,unitLabel:unitLabel,animate:animate,maxWidth:constraints.maxWidth),
      HudGaugeStyle.circular=>_CircularSpeed(speed:value,maxSpeed:maxSpeed,theme:theme,unitLabel:unitLabel,animate:animate,maxWidth:constraints.maxWidth),
    }));
}
class _DigitalGtSpeed extends StatelessWidget {
  const _DigitalGtSpeed({required this.speed,required this.theme,required this.unitLabel,required this.maxWidth,required this.layout,required this.gForce,required this.longitudinalAccel,required this.gear});
  final double speed,maxWidth; final HudTheme theme; final String unitLabel; final GtLayout layout; final double gForce,longitudinalAccel; final int gear;
  @override Widget build(BuildContext context){
    final width=math.min(430.0,maxWidth*.52);
    final fontSize=math.min(126.0,math.max(82.0,width*.30));
    if (layout == GtLayout.sport) {
      return SizedBox(width:width,height:190,child:Stack(alignment:Alignment.center,children:[
        Positioned.fill(child:CustomPaint(painter:_SportGtPainter(progress:(speed/240.0).clamp(0.0,1.0).toDouble(),theme:theme))),
        Positioned(top:6,left:10,child:_SportTelemetry(label:'G',value:gForce.toStringAsFixed(2),theme:theme)),
        Positioned(top:6,right:10,child:_SportTelemetry(label:'GEAR',value:gear==0?'N':gear.toString(),theme:theme)),
        Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:fontSize*1.08,fontWeight:FontWeight.w900,height:.82,letterSpacing:-5)),
        Positioned(bottom:24,left:18,right:18,child:_SportAccelBar(accel:longitudinalAccel,theme:theme)),
        Positioned(bottom:4,child:Text('SPORT GT',style:TextStyle(color:theme.secondary,fontSize:11,fontWeight:FontWeight.w900,letterSpacing:2))),
      ]));
    }
    if (layout == GtLayout.touring) {
      return Container(width:360,height:128,padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),decoration:BoxDecoration(color:Colors.black.withValues(alpha:.55),borderRadius:BorderRadius.circular(28),border:Border.all(color:theme.secondary.withValues(alpha:.45))),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        SizedBox(width:54,height:100,child:CustomPaint(painter:_TouringGtBars(progress:(speed/240.0).clamp(0.0,1.0).toDouble(),theme:theme))),
        const SizedBox(width:10),
        Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(speed.toStringAsFixed(0),style:TextStyle(color:theme.accent,fontSize:68,fontWeight:FontWeight.w800,height:.8)),
          Text(unitLabel.toUpperCase(),style:TextStyle(color:theme.secondary,fontSize:10,fontWeight:FontWeight.w800,letterSpacing:2)),
          const SizedBox(height:3),Text('TOURING GT',style:TextStyle(color:theme.secondary.withValues(alpha:.7),fontSize:9,fontWeight:FontWeight.w700,letterSpacing:2)),
        ]),
        const SizedBox(width:16),
        _MiniGForceGauge(gForce:gForce,theme:theme),
      ]));
    }
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
class _SportTelemetry extends StatelessWidget {
  const _SportTelemetry({required this.label,required this.value,required this.theme});
  final String label,value; final HudTheme theme;
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    Text(label,style:TextStyle(color:theme.secondary,fontSize:8,fontWeight:FontWeight.w800,letterSpacing:1.5)),
    Text(value,style:TextStyle(color:theme.accent,fontSize:18,fontWeight:FontWeight.w900,height:.9)),
  ]);
}
class _SportAccelBar extends StatelessWidget {
  const _SportAccelBar({required this.accel,required this.theme});
  final double accel; final HudTheme theme;
  @override Widget build(BuildContext context)=>SizedBox(height:18,child:CustomPaint(painter:_SportAccelPainter(accel:accel,theme:theme)));
}
class _SportAccelPainter extends CustomPainter {
  const _SportAccelPainter({required this.accel,required this.theme});
  final double accel; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final base=Paint()..color=theme.secondary.withValues(alpha:.14);
    final active=Paint()..color=theme.accent;
    final mid=size.width/2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0,7,size.width,4),const Radius.circular(2)),base);
    final v=(accel/6).clamp(-1.0,1.0).toDouble();
    final x=mid+v*mid;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(math.min(mid,x),7,(x-mid).abs(),4),const Radius.circular(2)),active);
    canvas.drawCircle(Offset(x,9),5,active);
  }
  @override bool shouldRepaint(covariant _SportAccelPainter old)=>old.accel!=accel||old.theme!=theme;
}
class _MiniGForceGauge extends StatelessWidget {
  const _MiniGForceGauge({required this.gForce,required this.theme});
  final double gForce;
  final HudTheme theme;
  @override Widget build(BuildContext context) => SizedBox(
    width:62,height:78,
    child:CustomPaint(
      painter:_MiniGForcePainter(gForce:gForce,theme:theme),
      child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(gForce.toStringAsFixed(2),style:TextStyle(color:theme.accent,fontSize:19,fontWeight:FontWeight.w900,height:.9)),
        Text('G',style:TextStyle(color:theme.secondary,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:1.5)),
      ])),
    ),
  );
}
class _MiniGForcePainter extends CustomPainter {
  const _MiniGForcePainter({required this.gForce,required this.theme});
  final double gForce; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height/2);
    final radius=math.min(size.width,size.height)*.42;
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=4..color=theme.secondary.withValues(alpha:.16);
    final active=Paint()..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round..color=theme.accent;
    canvas.drawCircle(center,radius,base);
    final v=(gForce.abs()/.8).clamp(0.0,1.0).toDouble();
    canvas.drawArc(Rect.fromCircle(center:center,radius:radius),-math.pi/2,math.pi*2*v,false,active);
    final axis=Paint()..color=theme.secondary.withValues(alpha:.2)..strokeWidth=1;
    canvas.drawLine(Offset(center.dx-radius*.65,center.dy),Offset(center.dx+radius*.65,center.dy),axis);
    canvas.drawLine(Offset(center.dx,center.dy-radius*.65),Offset(center.dx,center.dy+radius*.65),axis);
    final dot=Paint()..color=theme.accent;
    final dx=(gForce.clamp(-1.0,1.0))*radius*.5;
    canvas.drawCircle(center+Offset(dx,0),3,dot);
  }
  @override bool shouldRepaint(covariant _MiniGForcePainter old)=>old.gForce!=gForce||old.theme!=theme;
}
class _DigitalGtArcPainter extends CustomPainter {
  const _DigitalGtArcPainter({required this.progress,required this.theme}); final double progress; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height*.92); final radius=math.min(size.width*.39,size.height*1.45); final rect=Rect.fromCircle(center:center,radius:radius);
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=3..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.14);
    final active=Paint()..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round..color=theme.accent.withValues(alpha:.8);
    canvas.drawArc(rect,math.pi*1.15,math.pi*.70,false,base); canvas.drawArc(rect,math.pi*1.15,math.pi*.70*progress,false,active);
    final road=Path()
      ..moveTo(size.width*.50,size.height*.98)
      ..cubicTo(size.width*.43,size.height*.78,size.width*.66,size.height*.62,size.width*.50,size.height*.43)
      ..cubicTo(size.width*.38,size.height*.28,size.width*.57,size.height*.17,size.width*.50,size.height*.05);
    final roadPaint=Paint()..style=PaintingStyle.stroke..strokeWidth=math.max(18,size.width*.055)..strokeCap=StrokeCap.round..color=Colors.black.withValues(alpha:.68);
    final roadEdge=Paint()..style=PaintingStyle.stroke..strokeWidth=2..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.22);
    final lane=Paint()..style=PaintingStyle.stroke..strokeWidth=2..strokeCap=StrokeCap.round..color=theme.accent.withValues(alpha:.48);
    canvas.drawPath(road,roadPaint); canvas.drawPath(road,roadEdge);
    // Moving lane markers: progress advances the road rhythm so the NAV
    // cluster feels like the car is travelling through the road rather than
    // displaying a static decorative path.
    final metric=road.computeMetrics().first;
    final dashSpacing=18.0;
    final dashLength=8.0;
    final phase=(progress*metric.length*1.8)%dashSpacing;
    for(double d=-dashSpacing+phase; d<metric.length; d+=dashSpacing){
      if(d<0) continue;
      canvas.drawPath(metric.extractPath(d,math.min(d+dashLength,metric.length)),lane);
    }

    // Perspective car marker at the driver's end of the road.
    final carCenter=Offset(size.width*.50,size.height*.91);
    final carGlow=Paint()..color=theme.accent.withValues(alpha:.16);
    canvas.drawCircle(carCenter,10,carGlow);
    final car=Paint()..color=theme.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center:carCenter,width:7,height:13),
        const Radius.circular(3),
      ),
      car,
    );

    // Small directional chevrons give the path a subtle forward-motion cue.
    final chevron=Paint()
      ..style=PaintingStyle.stroke
      ..strokeWidth=1.4
      ..strokeCap=StrokeCap.round
      ..color=theme.secondary.withValues(alpha:.30);
    for(final t in <double>[.30,.52,.74]){
      final p=road.computeMetrics().first.getTangentForOffset(metric.length*t);
      if(p==null) continue;
      final c=p.position;
      canvas.drawLine(c+const Offset(-4,3),c,chevron);
      canvas.drawLine(c,c+const Offset(4,3),chevron);
    }
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

class _SportGtPainter extends CustomPainter {
  const _SportGtPainter({required this.progress,required this.theme});
  final double progress; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final p=Paint()..style=PaintingStyle.stroke..strokeWidth=9..strokeCap=StrokeCap.square..color=theme.secondary.withValues(alpha:.16);
    final a=Paint()..style=PaintingStyle.stroke..strokeWidth=9..strokeCap=StrokeCap.square..color=theme.accent;
    final rect=Rect.fromLTWH(8,12,size.width-16,size.height-28);
    canvas.drawArc(rect,math.pi*1.05,math.pi*.9,false,p);
    canvas.drawArc(rect,math.pi*1.05,math.pi*.9*progress,false,a);
  }
  @override bool shouldRepaint(covariant _SportGtPainter old)=>old.progress!=progress||old.theme!=theme;
}
class _TouringGtBars extends CustomPainter {
  const _TouringGtBars({required this.progress,required this.theme});
  final double progress; final HudTheme theme;
  @override void paint(Canvas canvas,Size size){
    final filled=(progress*8).ceil();
    for(var i=0;i<8;i++){final h=8+i*2.2;final rect=Rect.fromLTWH(4,size.height-10-h,12,h);canvas.drawRRect(RRect.fromRectAndRadius(rect,const Radius.circular(4)),Paint()..color=(i<filled?theme.accent:theme.secondary.withValues(alpha:.18)));}
  }
  @override bool shouldRepaint(covariant _TouringGtBars old)=>old.progress!=progress||old.theme!=theme;
}
