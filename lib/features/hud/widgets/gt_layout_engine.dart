import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/hud_theme.dart';
import '../../navigation/navigation_models.dart';

class GtLayoutSpec {
  const GtLayoutSpec({required this.showMap,required this.showFullSignRail,required this.showGForce,required this.showTrip,required this.showEta,required this.showRoadName,required this.compactNavigation});
  final bool showMap,showFullSignRail,showGForce,showTrip,showEta,showRoadName,compactNavigation;
}

class GtLayoutEngine {
  static GtLayoutSpec spec(GtLayout layout)=>switch(layout){
    GtLayout.nav=>const GtLayoutSpec(showMap:true,showFullSignRail:true,showGForce:false,showTrip:true,showEta:true,showRoadName:true,compactNavigation:false),
    GtLayout.sport=>const GtLayoutSpec(showMap:false,showFullSignRail:false,showGForce:true,showTrip:false,showEta:false,showRoadName:false,compactNavigation:true),
    GtLayout.touring=>const GtLayoutSpec(showMap:true,showFullSignRail:true,showGForce:true,showTrip:true,showEta:true,showRoadName:true,compactNavigation:false),
  };
  static String label(GtLayout layout)=>switch(layout){GtLayout.nav=>'NAV GT',GtLayout.sport=>'SPORT GT',GtLayout.touring=>'TOURING GT'};
}

class GtRouteMap extends StatelessWidget {
  const GtRouteMap({super.key,required this.route,required this.position,required this.theme,this.nextManeuver,this.compact=false,this.headingDegrees=0,this.speedKmh=0});
  final List<LatLng> route;
  final LatLng? position;
  final HudTheme theme;
  final NavigationManeuver? nextManeuver; final bool compact;
  // Heading and speed drive the "track-up" follow mode below: below
  // walking-pace the heading isn't reliable, so the map falls back to a
  // static full-route overview instead of jittering around.
  final double headingDegrees; final double speedKmh;
  @override
  Widget build(BuildContext context)=>Container(
    width: compact ? 210 : 220,
    height: compact ? 98 : 104,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha:.58),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color:theme.secondary.withValues(alpha:.42)),
    ),
    child: CustomPaint(
      painter:_GtRoutePainter(
        route:route,
        position:position,
        theme:theme,
        nextManeuver:nextManeuver,
        headingDegrees:headingDegrees,
        following: position != null && speedKmh >= 5,
      ),
    ),
  );
}

class _GtRoutePainter extends CustomPainter {
  const _GtRoutePainter({required this.route,required this.position,required this.theme,required this.nextManeuver,required this.headingDegrees,required this.following});
  final List<LatLng> route; final LatLng? position; final HudTheme theme; final NavigationManeuver? nextManeuver;
  final double headingDegrees; final bool following;

  static const _metersPerDegreeLat = 111320.0;
  // How much road is visible ahead vs behind the vehicle in follow mode.
  static const _aheadMeters = 160.0;
  static const _behindMeters = 55.0;

  Offset _metersFrom(LatLng origin, LatLng point) {
    final latRad = origin.latitude * math.pi / 180.0;
    final cosLat = math.max(0.1, math.cos(latRad));
    final dx = (point.longitude - origin.longitude) * _metersPerDegreeLat * cosLat;
    final dy = (point.latitude - origin.latitude) * _metersPerDegreeLat;
    return Offset(dx, dy);
  }

  @override void paint(Canvas canvas,Size size){
    if(route.length<2){_label(canvas,size,'MAP • WAITING FOR ROUTE');return;}
    if (following && position != null) {
      _paintFollowing(canvas, size, position!);
    } else {
      _paintOverview(canvas, size);
    }
  }

  /// "Track-up" mode: the vehicle stays anchored near the bottom of the
  /// widget and the route rotates so the direction of travel always points
  /// up, the way real turn-by-turn navigation displays behave. This is what
  /// makes the mini-map actually *track* the drive instead of showing a
  /// static overview of the whole route regardless of where the car is.
  void _paintFollowing(Canvas canvas, Size size, LatLng vehicle) {
    final metersPerPixel = (_aheadMeters + _behindMeters) / size.height;
    final headingRad = headingDegrees * math.pi / 180.0;
    final cosH = math.cos(-headingRad), sinH = math.sin(-headingRad);
    final anchor = Offset(size.width / 2, size.height * 0.72);

    Offset project(LatLng p) {
      final m = _metersFrom(vehicle, p);
      final rx = m.dx * cosH - m.dy * sinH;
      final ry = m.dx * sinH + m.dy * cosH;
      return Offset(anchor.dx + rx / metersPerPixel, anchor.dy - ry / metersPerPixel);
    }

    final path = ui.Path()..moveTo(project(route.first).dx, project(route.first).dy);
    for (final p in route.skip(1)) {
      final q = project(p);
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=7..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.25));
    canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=3..strokeCap=StrokeCap.round..color=theme.accent);
    if(nextManeuver!=null){final q=project(nextManeuver!.position);canvas.drawCircle(q,5,Paint()..color=theme.accent);}

    // Vehicle marker stays fixed at the anchor; since the map rotates
    // instead of the marker, a simple up-pointing arrow always reads as
    // "forward" correctly.
    canvas.drawCircle(anchor,7,Paint()..color=Colors.white);
    final arrow = ui.Path()
      ..moveTo(anchor.dx, anchor.dy - 8)
      ..lineTo(anchor.dx - 5, anchor.dy + 5)
      ..lineTo(anchor.dx + 5, anchor.dy + 5)
      ..close();
    canvas.drawPath(arrow, Paint()..color=theme.accent);
  }

  /// Fallback for when the vehicle is stationary/slow (no reliable
  /// heading): the previous whole-route overview.
  void _paintOverview(Canvas canvas,Size size){
    final points=<LatLng>[...route,if(position!=null)position!];
    final minLat=points.map((p)=>p.latitude).reduce(math.min),maxLat=points.map((p)=>p.latitude).reduce(math.max);
    final minLon=points.map((p)=>p.longitude).reduce(math.min),maxLon=points.map((p)=>p.longitude).reduce(math.max);
    final latSpan=math.max((maxLat-minLat).abs(),.0001),lonSpan=math.max((maxLon-minLon).abs(),.0001);
    Offset project(LatLng p)=>Offset(10+(p.longitude-minLon)/lonSpan*(size.width-20),size.height-(10+(p.latitude-minLat)/latSpan*(size.height-20)));
    final path=ui.Path()..moveTo(project(route.first).dx,project(route.first).dy);
    for(final p in route.skip(1)){final q=project(p);path.lineTo(q.dx,q.dy);}
    canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=7..strokeCap=StrokeCap.round..color=theme.secondary.withValues(alpha:.25));
    canvas.drawPath(path,Paint()..style=PaintingStyle.stroke..strokeWidth=3..strokeCap=StrokeCap.round..color=theme.accent);
    if(position!=null){final q=project(position!);canvas.drawCircle(q,7,Paint()..color=Colors.white);canvas.drawCircle(q,4,Paint()..color=theme.accent);}
    if(nextManeuver!=null){final q=project(nextManeuver!.position);canvas.drawCircle(q,5,Paint()..color=theme.accent);}
  }
  void _label(Canvas canvas,Size size,String value){final tp=TextPainter(text:TextSpan(text:value,style:TextStyle(color:theme.secondary,fontSize:9,fontWeight:FontWeight.w800)),textDirection:TextDirection.ltr)..layout();tp.paint(canvas,Offset((size.width-tp.width)/2,(size.height-tp.height)/2));}
  @override bool shouldRepaint(covariant _GtRoutePainter old)=>old.route!=route||old.position!=position||old.theme!=theme||old.nextManeuver!=nextManeuver||old.headingDegrees!=headingDegrees||old.following!=following;
}
