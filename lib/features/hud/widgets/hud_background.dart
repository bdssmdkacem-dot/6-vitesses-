import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class HudBackground extends StatefulWidget {
  const HudBackground({super.key,required this.theme,this.animate=true});
  final HudTheme theme; final bool animate;
  @override State<HudBackground> createState()=>_HudBackgroundState();
}
class _HudBackgroundState extends State<HudBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override void initState(){super.initState();_controller=AnimationController(vsync:this,duration:const Duration(seconds:8));if(widget.animate)_controller.repeat();}
  @override void didUpdateWidget(covariant HudBackground old){super.didUpdateWidget(old);if(widget.animate&&!old.animate)_controller.repeat();else if(!widget.animate&&old.animate)_controller.stop();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:_controller,builder:(_,__)=>CustomPaint(painter:_BackgroundPainter(widget.theme,_controller.value),child:const SizedBox.expand()));
  @override void dispose(){_controller.dispose();super.dispose();}
}
class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter(this.theme,this.progress); final HudTheme theme; final double progress;
  @override void paint(Canvas canvas,Size size){canvas.drawRect(Offset.zero&size,Paint()..color=theme.background);switch(theme.backgroundStyle){case HudBackgroundStyle.solid:_vignette(canvas,size);case HudBackgroundStyle.carbon:_carbon(canvas,size);case HudBackgroundStyle.grid:_grid(canvas,size);case HudBackgroundStyle.road:_road(canvas,size);case HudBackgroundStyle.night:_night(canvas,size);}}
  void _vignette(Canvas canvas,Size size){final center=size.center(Offset.zero),r=size.longestSide*.7;canvas.drawCircle(center,r,Paint()..shader=RadialGradient(colors:[theme.accent.withValues(alpha:.035),Colors.transparent]).createShader(Rect.fromCircle(center:center,radius:r)));}
  void _carbon(Canvas canvas,Size size){final p=Paint()..color=theme.secondary.withValues(alpha:.07);const d=28.0;final shift=progress*d;for(double x=-size.height-d;x<size.width+d;x+=d){canvas.drawRect(Rect.fromLTWH(x+shift,0,d/2,size.height),p);}_vignette(canvas,size);}
  void _grid(Canvas canvas,Size size){final p=Paint()..color=theme.secondary.withValues(alpha:.11)..strokeWidth=1;final shift=progress*36;for(double x=-36;x<size.width+36;x+=36){canvas.drawLine(Offset(x+shift,0),Offset(x+shift,size.height),p);}for(double y=-36;y<size.height+36;y+=36){canvas.drawLine(Offset(0,y+shift),Offset(size.width,y+shift),p);}}
  void _road(Canvas canvas,Size size){final center=size.width/2;final road=Path()..moveTo(center-size.width*.08,size.height)..lineTo(center-size.width*.012,size.height*.45)..lineTo(center+size.width*.012,size.height*.45)..lineTo(center+size.width*.08,size.height)..close();canvas.drawPath(road,Paint()..color=theme.secondary.withValues(alpha:.10));final line=Paint()..color=theme.accent.withValues(alpha:.18);canvas.drawLine(Offset(center,size.height),Offset(center,size.height*.48),line);for(var i=0;i<6;i++){final t=(i/6+progress)%1;final y=size.height*(.48+t*.48);final half=size.width*(.012+t*.055);line.strokeWidth=2+t*3;canvas.drawLine(Offset(center-half,y),Offset(center+half,y),line);}}
  void _night(Canvas canvas,Size size){final p=Paint()..color=theme.secondary.withValues(alpha:.25);final random=math.Random(7);for(var i=0;i<80;i++){final x=random.nextDouble()*size.width,y=random.nextDouble()*size.height*.7;canvas.drawCircle(Offset(x,y),random.nextDouble()*1.4+.3,p);}}
  @override bool shouldRepaint(covariant _BackgroundPainter old)=>old.theme!=theme||old.progress!=progress;
}
