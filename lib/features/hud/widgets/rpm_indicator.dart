import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hud_theme.dart';

class RpmIndicator extends StatelessWidget {
  const RpmIndicator({super.key,required this.rpm,required this.theme,this.style=HudRpmStyle.arc,this.animate=true});
  final double? rpm; final HudTheme theme; final HudRpmStyle style; final bool animate;
  double get normalized=>((rpm??0)/8000).clamp(0.0,1.0);
  @override Widget build(BuildContext context)=>SizedBox(
    width:250,height:style==HudRpmStyle.arc?82:58,
    child:TweenAnimationBuilder<double>(
      tween:Tween(begin:0,end:normalized),
      duration:animate?const Duration(milliseconds:280):Duration.zero,
      curve:Curves.easeOutCubic,
      builder:(context,value,_)=>CustomPaint(
        painter:_RpmPainter(value:value,theme:theme,style:style,available:rpm!=null),
        child:Center(child:Text(rpm==null?'RPM  OBD':'RPM  ${rpm!.round()}',
          style:TextStyle(color: rpm==null?theme.secondary:theme.accent,fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.2))),
      ),
    ),
  );
}
class _RpmPainter extends CustomPainter {
  const _RpmPainter({required this.value,required this.theme,required this.style,required this.available});
  final double value; final HudTheme theme; final HudRpmStyle style; final bool available;
  @override void paint(Canvas canvas,Size size){
    final base=Paint()..style=PaintingStyle.stroke..strokeWidth=7..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.18);
    final active=Paint()..style=PaintingStyle.stroke..strokeWidth=7..strokeCap=StrokeCap.round..color=available?theme.accent:theme.secondary.withValues(alpha:.25);
    if(style==HudRpmStyle.arc){final rect=Rect.fromLTWH(10,4,size.width-20,size.height*1.65);canvas.drawArc(rect,math.pi*1.08,math.pi*.84,false,base);canvas.drawArc(rect,math.pi*1.08,math.pi*.84*value,false,active);return;}
    if(style==HudRpmStyle.strip){canvas.drawLine(Offset(10,size.height/2),Offset(size.width-10,size.height/2),base);canvas.drawLine(Offset(10,size.height/2),Offset(10+(size.width-20)*value,size.height/2),active);return;}
    final barWidth=(size.width-28)/8;
    for(var i=0;i<8;i++){final x=8+i*(barWidth+2);final filled=value*8>=i+1;final p=Paint()..color=filled&&available?theme.accent:theme.secondary.withValues(alpha:.16);canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,size.height-18,barWidth,10),const Radius.circular(3)),p);}
  }
  @override bool shouldRepaint(covariant _RpmPainter o)=>o.value!=value||o.theme!=theme||o.style!=style||o.available!=available;
}
