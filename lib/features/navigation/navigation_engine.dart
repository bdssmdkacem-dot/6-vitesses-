import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'navigation_models.dart';
import 'osrm_route_service.dart';

class NavigationEngine {
  const NavigationEngine();

  NavigationState update({
    required OsrmRoute route,
    required LatLng position,
    double speedKmh = 0,
    double headingDegrees = 0,
  }) {
    final distance = const Distance();
    final tracking = _routeTracking(route.geometry, position, distance);
    var nextIndex = _nextManeuverIndex(
      route.maneuvers,
      route.geometry,
      tracking.alongMeters,
      distance,
    );
    if (nextIndex < 0 && route.maneuvers.isNotEmpty) {
      nextIndex = route.maneuvers.length - 1;
    }
    final remaining = tracking.remainingMeters;
    final nextManeuverDistance = _distanceToNextManeuver(
      route.maneuvers,
      route.geometry,
      tracking.alongMeters,
      nextIndex,
      distance,
    );
    final baselineSpeedMps = route.durationSeconds > 0 && route.distanceMeters > 0
        ? route.distanceMeters / route.durationSeconds
        : 13.9;
    final currentSpeedMps = speedKmh > 2 ? speedKmh / 3.6 : baselineSpeedMps;
    final etaSeconds = remaining <= 1.0
        ? 0.0
        : (remaining / math.max(1.0, currentSpeedMps)).toDouble();

    final routeBearing = tracking.bearingDegrees;
    final headingDelta = _angularDifference(headingDegrees, routeBearing);
    final accuracyThreshold = 35.0;
    final offRoute = tracking.distanceFromRouteMeters > accuracyThreshold ||
        (speedKmh > 15 && headingDelta > 75 && tracking.distanceFromRouteMeters > 18);

    return NavigationState(
      route: route.geometry,
      maneuvers: route.maneuvers,
      nextIndex: nextIndex,
      remainingMeters: remaining,
      remainingSeconds: etaSeconds,
      distanceFromRouteMeters: tracking.distanceFromRouteMeters,
      offRoute: offRoute,
      routeBearingDegrees: routeBearing,
      nextManeuverDistanceMeters: nextManeuverDistance,
      routeProgressMeters: tracking.alongMeters,
      routeTotalMeters: route.distanceMeters,
    );
  }

  _RouteTracking _routeTracking(List<LatLng> geometry, LatLng position, Distance distance) {
    if (geometry.isEmpty) return const _RouteTracking(0, 0, 0);
    if (geometry.length == 1) {
      return _RouteTracking(
        distance.as(LengthUnit.Meter, position, geometry.first),
        0,
        0,
        0,
      );
    }

    var bestSegment = 0;
    var bestScore = double.infinity;
    var bestAlong = 0.0;
    var bestDistance = double.infinity;

    for (var i = 0; i < geometry.length - 1; i++) {
      final start = geometry[i];
      final end = geometry[i + 1];
      final segmentMeters = distance.as(LengthUnit.Meter, start, end);
      if (segmentMeters <= 0) continue;
      final startDistance = distance.as(LengthUnit.Meter, position, start);
      final endDistance = distance.as(LengthUnit.Meter, position, end);
      final fraction = (startDistance / math.max(0.001, startDistance + endDistance)).clamp(0.0, 1.0).toDouble();
      final projected = _interpolate(start, end, fraction);
      final crossTrack = distance.as(LengthUnit.Meter, position, projected);
      final score = crossTrack + math.min(startDistance, endDistance) * 0.05;
      if (score < bestScore) {
        bestScore = score;
        bestSegment = i;
        bestAlong = segmentMeters * fraction;
        bestDistance = crossTrack;
      }
    }

    final segmentLength = distance.as(
      LengthUnit.Meter,
      geometry[bestSegment],
      geometry[bestSegment + 1],
    );
    final remainingOnSegment = math.max(0.0, segmentLength - bestAlong).toDouble();
    var beforeSegment = 0.0;
    for (var i = 0; i < bestSegment; i++) {
      beforeSegment += distance.as(LengthUnit.Meter, geometry[i], geometry[i + 1]);
    }
    final alongMeters = beforeSegment + bestAlong;
    var remaining = remainingOnSegment;
    for (var i = bestSegment + 1; i < geometry.length - 1; i++) {
      remaining += distance.as(LengthUnit.Meter, geometry[i], geometry[i + 1]);
    }

    return _RouteTracking(
      remaining,
      bestDistance,
      distance.bearing(geometry[bestSegment], geometry[bestSegment + 1]),
      alongMeters,
    );
  }

  LatLng _interpolate(LatLng a, LatLng b, double fraction) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * fraction,
      a.longitude + (b.longitude - a.longitude) * fraction,
    );
  }

  double _angularDifference(double a, double b) {
    final delta = (a - b).abs() % 360;
    return delta > 180 ? 360 - delta : delta;
  }

double _distanceToNextManeuver(
  List<NavigationManeuver> maneuvers,
  List<LatLng> geometry,
  double alongMeters,
  int index,
  Distance distance,
) {
  if (index < 0 || index >= maneuvers.length || geometry.isEmpty) return 0;
  var bestIndex = 0;
  var bestDistance = double.infinity;
  final maneuver = maneuvers[index];
  for (var i = 0; i < geometry.length; i++) {
    final d = distance.as(LengthUnit.Meter, maneuver.position, geometry[i]);
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
    }
  }
  var maneuverAlong = 0.0;
  for (var i = 0; i < bestIndex && i < geometry.length - 1; i++) {
    maneuverAlong += distance.as(LengthUnit.Meter, geometry[i], geometry[i + 1]);
  }
  return math.max(0.0, maneuverAlong - alongMeters).toDouble();
}

int _nextManeuverIndex(
    List<NavigationManeuver> maneuvers,
    List<LatLng> geometry,
    double alongMeters,
    Distance distance,
  ) {
    if (maneuvers.isEmpty) return -1;
    final maneuverAlong = <double>[];
    for (final maneuver in maneuvers) {
      var bestIndex = 0;
      var bestDistance = double.infinity;
      for (var i = 0; i < geometry.length; i++) {
        final d = distance.as(LengthUnit.Meter, maneuver.position, geometry[i]);
        if (d < bestDistance) {
          bestDistance = d;
          bestIndex = i;
        }
      }
      var along = 0.0;
      for (var i = 0; i < bestIndex && i < geometry.length - 1; i++) {
        along += distance.as(LengthUnit.Meter, geometry[i], geometry[i + 1]);
      }
      maneuverAlong.add(along);
    }

    const triggerMeters = 18.0;
    for (var i = 0; i < maneuverAlong.length; i++) {
      if (maneuverAlong[i] >= alongMeters - triggerMeters) return i;
    }
    return maneuvers.length - 1;
  }
}

class _RouteTracking {
  const _RouteTracking(this.remainingMeters, this.distanceFromRouteMeters, this.bearingDegrees, [this.alongMeters = 0]);
  final double remainingMeters;
  final double distanceFromRouteMeters;
  final double bearingDegrees;
  final double alongMeters;
}
