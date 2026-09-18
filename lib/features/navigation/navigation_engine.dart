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
    double? previousRouteProgressMeters,
    int? previousRouteSegmentIndex,
  }) {
    final distance = const Distance();
    final tracking = _routeTracking(
      route.geometry,
      position,
      distance,
      headingDegrees,
      speedKmh,
      previousRouteProgressMeters,
      previousRouteSegmentIndex,
    );

    final maneuverAlong = <double>[
      for (final maneuver in route.maneuvers)
        _maneuverAlong(route.geometry, maneuver.position, distance),
    ];

    var nextIndex = _nextManeuverIndex(
      route.maneuvers,
      maneuverAlong,
      tracking.alongMeters,
    );
    if (nextIndex < 0 && route.maneuvers.isNotEmpty) {
      nextIndex = route.maneuvers.length - 1;
    }

    final remaining =
        math.max(0.0, route.distanceMeters - tracking.alongMeters).toDouble();
    final nextManeuverDistance = nextIndex < 0
        ? 0.0
        : math.max(
            0.0,
            maneuverAlong[nextIndex] - tracking.alongMeters,
          ).toDouble();

    final baselineSpeedMps =
        route.durationSeconds > 0 && route.distanceMeters > 0
            ? route.distanceMeters / route.durationSeconds
            : 13.9;
    final currentSpeedMps =
        speedKmh > 2 ? speedKmh / 3.6 : baselineSpeedMps;
    final etaSeconds = remaining <= 1.0
        ? 0.0
        : (remaining / math.max(1.0, currentSpeedMps)).toDouble();

    final routeBearing = tracking.bearingDegrees;
    final headingIsReliable = speedKmh >= 5;
    final headingDelta =
        _angularDifference(headingDegrees, routeBearing);
    final offRoute = tracking.distanceFromRouteMeters > 35 ||
        (speedKmh > 15 &&
            headingIsReliable &&
            headingDelta > 75 &&
            tracking.distanceFromRouteMeters > 18);

    final enrichedManeuvers = <NavigationManeuver>[
      for (var i = 0; i < route.maneuvers.length; i++)
        _enrichManeuver(
          route.maneuvers[i],
          route.maneuvers[i].routeProgressMeters ?? maneuverAlong[i],
          route.maneuvers[i].routeSegmentIndex ??
              _maneuverSegmentIndex(
                route.geometry,
                route.maneuvers[i].position,
                distance,
              ),
        ),
    ];

    return NavigationState(
      route: route.geometry,
      maneuvers: enrichedManeuvers,
      nextIndex: nextIndex,
      remainingMeters: remaining,
      remainingSeconds: etaSeconds,
      distanceFromRouteMeters: tracking.distanceFromRouteMeters,
      offRoute: offRoute,
      routeBearingDegrees: routeBearing,
      nextManeuverDistanceMeters: nextManeuverDistance,
      routeProgressMeters: tracking.alongMeters,
      routeTotalMeters: route.distanceMeters,
      routeSegmentIndex: tracking.segmentIndex,
    );
  }

  NavigationManeuver _enrichManeuver(
    NavigationManeuver maneuver,
    double alongMeters,
    int segmentIndex,
  ) {
    return NavigationManeuver(
      type: maneuver.type,
      position: maneuver.position,
      distanceMeters: maneuver.distanceMeters,
      name: maneuver.name,
      modifier: maneuver.modifier,
      exitNumber: maneuver.exitNumber,
      bearingBefore: maneuver.bearingBefore,
      bearingAfter: maneuver.bearingAfter,
      roadRef: maneuver.roadRef,
      routeProgressMeters: alongMeters,
      routeSegmentIndex: segmentIndex,
    );
  }

  _RouteTracking _routeTracking(
    List<LatLng> geometry,
    LatLng position,
    Distance distance,
    double headingDegrees,
    double speedKmh,
    double? previousRouteProgressMeters,
    int? previousRouteSegmentIndex,
  ) {
    if (geometry.isEmpty) {
      return const _RouteTracking(
        remainingMeters: 0,
        distanceFromRouteMeters: 0,
        bearingDegrees: 0,
        alongMeters: 0,
        segmentIndex: 0,
      );
    }
    if (geometry.length == 1) {
      final pointDistance =
          distance.as(LengthUnit.Meter, position, geometry.first);
      return _RouteTracking(
        remainingMeters: pointDistance,
        distanceFromRouteMeters: pointDistance,
        bearingDegrees: 0,
        alongMeters: 0,
        segmentIndex: 0,
      );
    }

    var best = _ProjectionResult(
      segmentIndex: 0,
      fraction: 0,
      crossTrackMeters: double.infinity,
      score: double.infinity,
      bearingDegrees: 0,
    );
    var cumulative = 0.0;

    for (var i = 0; i < geometry.length - 1; i++) {
      final start = geometry[i];
      final end = geometry[i + 1];
      final segmentMeters = distance.as(LengthUnit.Meter, start, end);
      if (segmentMeters < 0.5) continue;

      final projection = _project(position, start, end);
      final bearing = distance.bearing(start, end);
      final headingIsReliable = speedKmh >= 5;
      final headingPenalty = !headingIsReliable
          ? 0.0
          : _angularDifference(headingDegrees, bearing) * 0.12;
      final candidateAlong =
          cumulative + segmentMeters * projection.fraction;
      final progressPenalty = previousRouteProgressMeters == null
          ? 0.0
          : _progressPenalty(candidateAlong, previousRouteProgressMeters);
      final segmentPenalty = previousRouteSegmentIndex == null
          ? 0.0
          : _segmentContinuityPenalty(
              i,
              previousRouteSegmentIndex,
              candidateAlong,
              previousRouteProgressMeters,
            );
      final score = projection.crossTrackMeters +
          headingPenalty +
          progressPenalty +
          segmentPenalty;

      if (score < best.score) {
        best = _ProjectionResult(
          segmentIndex: i,
          fraction: projection.fraction,
          crossTrackMeters: projection.crossTrackMeters,
          score: score,
          bearingDegrees: bearing,
        );
      }
      cumulative += segmentMeters;
    }

    var before = 0.0;
    for (var i = 0; i < best.segmentIndex; i++) {
      before +=
          distance.as(LengthUnit.Meter, geometry[i], geometry[i + 1]);
    }
    final segmentLength = distance.as(
      LengthUnit.Meter,
      geometry[best.segmentIndex],
      geometry[best.segmentIndex + 1],
    );
    final alongMeters = before + segmentLength * best.fraction;

    return _RouteTracking(
      remainingMeters: math.max(0.0, cumulative - alongMeters).toDouble(),
      distanceFromRouteMeters: best.crossTrackMeters,
      bearingDegrees: best.bearingDegrees,
      alongMeters: alongMeters,
      segmentIndex: best.segmentIndex,
    );
  }

  double _segmentContinuityPenalty(
    int candidateSegment,
    int previousSegment,
    double candidateAlong,
    double? previousProgress,
  ) {
    final jump = (candidateSegment - previousSegment).abs();
    if (jump <= 1) return 0;
    if (previousProgress != null &&
        candidateAlong >= previousProgress - 5 &&
        candidateAlong <= previousProgress + 80) {
      return math.min(18.0, (jump - 1) * 3.0);
    }
    return math.min(70.0, 12.0 + (jump - 1) * 8.0);
  }

  _ProjectionResult _project(LatLng point, LatLng start, LatLng end) {
    const metersPerDegree = 111320.0;
    final latRad =
        ((start.latitude + end.latitude) * 0.5) * math.pi / 180.0;
    final cosLat = math.max(0.01, math.cos(latRad));
    final dx =
        (end.longitude - start.longitude) * metersPerDegree * cosLat;
    final dy = (end.latitude - start.latitude) * metersPerDegree;
    final px =
        (point.longitude - start.longitude) * metersPerDegree * cosLat;
    final py = (point.latitude - start.latitude) * metersPerDegree;
    final denom = dx * dx + dy * dy;
    final fraction =
        denom <= 0.0001 ? 0.0 : (px * dx + py * dy) / denom;
    final clamped = fraction.clamp(0.0, 1.0).toDouble();
    final crossX = px - dx * clamped;
    final crossY = py - dy * clamped;
    return _ProjectionResult(
      segmentIndex: 0,
      fraction: clamped,
      crossTrackMeters: math.sqrt(crossX * crossX + crossY * crossY),
      score: 0,
      bearingDegrees: 0,
    );
  }

  double _maneuverAlong(
    List<LatLng> geometry,
    LatLng maneuver,
    Distance distance,
  ) {
    if (geometry.length < 2) return 0;
    var bestDistance = double.infinity;
    var bestAlong = 0.0;
    var cumulative = 0.0;
    for (var i = 0; i < geometry.length - 1; i++) {
      final start = geometry[i];
      final end = geometry[i + 1];
      final segmentLength = distance.as(LengthUnit.Meter, start, end);
      if (segmentLength < 0.5) continue;
      final projection = _project(maneuver, start, end);
      if (projection.crossTrackMeters < bestDistance) {
        bestDistance = projection.crossTrackMeters;
        bestAlong = cumulative + segmentLength * projection.fraction;
      }
      cumulative += segmentLength;
    }
    return bestAlong;
  }

  int _maneuverSegmentIndex(
    List<LatLng> geometry,
    LatLng maneuver,
    Distance distance,
  ) {
    if (geometry.length < 2) return 0;
    var bestDistance = double.infinity;
    var bestIndex = 0;
    for (var i = 0; i < geometry.length - 1; i++) {
      final segmentLength =
          distance.as(LengthUnit.Meter, geometry[i], geometry[i + 1]);
      if (segmentLength < 0.5) continue;
      final projection = _project(maneuver, geometry[i], geometry[i + 1]);
      if (projection.crossTrackMeters < bestDistance) {
        bestDistance = projection.crossTrackMeters;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int _nextManeuverIndex(
    List<NavigationManeuver> maneuvers,
    List<double> along,
    double progress,
  ) {
    if (maneuvers.isEmpty) return -1;
    const passedTolerance = 12.0;
    for (var i = 0; i < along.length; i++) {
      if (maneuvers[i].type == NavigationManeuverType.depart &&
          progress > 20) {
        continue;
      }
      if (along[i] >= progress - passedTolerance) return i;
    }
    return maneuvers.length - 1;
  }

  double _progressPenalty(double candidateAlong, double previousProgress) {
    final backwards = previousProgress - candidateAlong;
    if (backwards <= 8) return 0;
    final localWindow = math.max(0.0, previousProgress - 60);
    if (candidateAlong >= localWindow) return backwards * 0.8;
    final jump = localWindow - candidateAlong;
    return 48 + jump * 1.5;
  }

  double _angularDifference(double a, double b) {
    final delta = (a - b).abs() % 360;
    return delta > 180 ? 360 - delta : delta;
  }
}

class _ProjectionResult {
  const _ProjectionResult({
    required this.segmentIndex,
    required this.fraction,
    required this.crossTrackMeters,
    required this.score,
    required this.bearingDegrees,
  });
  final int segmentIndex;
  final double fraction;
  final double crossTrackMeters;
  final double score;
  final double bearingDegrees;
}

class _RouteTracking {
  const _RouteTracking({
    required this.remainingMeters,
    required this.distanceFromRouteMeters,
    required this.bearingDegrees,
    required this.alongMeters,
    required this.segmentIndex,
  });

  final double remainingMeters;
  final double distanceFromRouteMeters;
  final double bearingDegrees;
  final double alongMeters;
  final int segmentIndex;
}
