import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

enum TrafficSignType { stop, giveWay, speedLimit, trafficSignals, roundabout, crossing, motorway, oneWay, unknown }

class TrafficSign {
  const TrafficSign({required this.type, required this.position, this.value, this.name, this.directionDegrees});
  final TrafficSignType type;
  final LatLng position;
  final int? value;
  final String? name;
  final double? directionDegrees;
}

class RelevantTrafficSign {
  const RelevantTrafficSign({required this.sign, required this.distanceMeters, required this.bearingDegrees});
  final TrafficSign sign;
  final double distanceMeters;
  final double bearingDegrees;
}

class TrafficSignEngine {
  TrafficSignEngine({this.maxDistanceMeters = 1000, this.aheadToleranceDegrees = 70, this.routeToleranceMeters = 45});
  final double maxDistanceMeters;
  final double aheadToleranceDegrees;
  final double routeToleranceMeters;
  final Distance _distance = const Distance();

  List<RelevantTrafficSign> findRelevant({
    required LatLng vehiclePosition,
    required double headingDegrees,
    required Iterable<TrafficSign> signs,
    List<LatLng>? route,
  }) {
    final result = <RelevantTrafficSign>[];
    for (final sign in signs) {
      final distanceMeters = _distance.as(LengthUnit.Meter, vehiclePosition, sign.position);
      if (distanceMeters > maxDistanceMeters) continue;
      final bearing = _distance.bearing(vehiclePosition, sign.position);
      if (_angularDifference(headingDegrees, bearing) > aheadToleranceDegrees) continue;
      if (sign.directionDegrees != null && _angularDifference(sign.directionDegrees!, headingDegrees) > 100) continue;
      if (route != null && route.length >= 2) {
        final match = _routeMatch(sign.position, route);
        if (match.distanceMeters > routeToleranceMeters) continue;
        if (_angularDifference(headingDegrees, match.bearingDegrees) > aheadToleranceDegrees + 20) continue;
      }
      result.add(RelevantTrafficSign(sign: sign, distanceMeters: distanceMeters, bearingDegrees: bearing));
    }
    result.sort((a, b) => _priority(a.sign.type).compareTo(_priority(b.sign.type)) != 0
        ? _priority(a.sign.type).compareTo(_priority(b.sign.type))
        : a.distanceMeters.compareTo(b.distanceMeters));
    return result;
  }

  int _priority(TrafficSignType type) {
    switch (type) {
      case TrafficSignType.stop: return 0;
      case TrafficSignType.giveWay: return 1;
      case TrafficSignType.trafficSignals: return 2;
      case TrafficSignType.speedLimit: return 3;
      case TrafficSignType.roundabout: return 4;
      default: return 5;
    }
  }

  _RouteMatch _routeMatch(LatLng point, List<LatLng> route) {
    var best = _RouteMatch(double.infinity, 0);
    for (var i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final latRad = ((start.latitude + end.latitude) * 0.5) * math.pi / 180.0;
      final cosLat = math.max(0.01, math.cos(latRad));
      const scale = 111320.0;
      final dx = (end.longitude - start.longitude) * scale * cosLat;
      final dy = (end.latitude - start.latitude) * scale;
      final px = (point.longitude - start.longitude) * scale * cosLat;
      final py = (point.latitude - start.latitude) * scale;
      final denom = dx * dx + dy * dy;
      final f = denom <= 0.0001 ? 0.0 : (px * dx + py * dy) / denom;
      final fraction = f.clamp(0.0, 1.0).toDouble();
      final ex = px - dx * fraction;
      final ey = py - dy * fraction;
      final cross = math.sqrt(ex * ex + ey * ey);
      if (cross < best.distanceMeters) {
        best = _RouteMatch(cross, _distance.bearing(start, end));
      }
    }
    return best;
  }

  double _distanceToRoute(LatLng point, List<LatLng> route) {
    var best = double.infinity;
    for (var i = 0; i < route.length - 1; i++) {
      final start = route[i];
      final end = route[i + 1];
      final startDistance = _distance.as(LengthUnit.Meter, point, start);
      final endDistance = _distance.as(LengthUnit.Meter, point, end);
      final denominator = math.max(0.001, startDistance + endDistance).toDouble();
      final fraction = (startDistance / denominator).clamp(0.0, 1.0).toDouble();
      final projected = LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
      final cross = _distance.as(LengthUnit.Meter, point, projected);
      if (cross < best) best = cross;
    }
    return best;
  }

  double _angularDifference(double a, double b) {
    final delta = (a - b).abs() % 360;
    return delta > 180 ? 360 - delta : delta;
  }
}

TrafficSignType trafficSignTypeFromOsm(String value) {
  final normalized = value.toLowerCase().replaceAll('_', ':');
  if (normalized.contains('stop')) return TrafficSignType.stop;
  if (normalized.contains('give:way')) return TrafficSignType.giveWay;
  if (normalized.contains('maxspeed') || normalized.contains('speed')) return TrafficSignType.speedLimit;
  if (normalized.contains('traffic:signals') || normalized.contains('signals')) return TrafficSignType.trafficSignals;
  if (normalized.contains('roundabout')) return TrafficSignType.roundabout;
  if (normalized.contains('crossing')) return TrafficSignType.crossing;
  if (normalized.contains('motorway')) return TrafficSignType.motorway;
  if (normalized.contains('one:way') || normalized.contains('oneway')) return TrafficSignType.oneWay;
  return TrafficSignType.unknown;
}
