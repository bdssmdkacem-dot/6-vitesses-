import 'package:latlong2/latlong.dart';
import 'navigation_models.dart';
import 'osrm_route_service.dart';

class NavigationEngine {
  const NavigationEngine();

  NavigationState update({
    required OsrmRoute route,
    required LatLng position,
  }) {
    final distance = const Distance();
    var nearestIndex = 0;
    var nearestMeters = double.infinity;

    for (var i = 0; i < route.maneuvers.length; i++) {
      final meters = distance.as(
        LengthUnit.Meter,
        position,
        route.maneuvers[i].position,
      );
      if (meters < nearestMeters) {
        nearestMeters = meters;
        nearestIndex = i;
      }
    }

    var nextIndex = route.maneuvers.isEmpty ? -1 : nearestIndex;
    if (nextIndex >= 0) {
      while (nextIndex < route.maneuvers.length - 1 &&
          distance.as(
                LengthUnit.Meter,
                position,
                route.maneuvers[nextIndex].position,
              ) <
              18) {
        nextIndex++;
      }
    }

    return NavigationState(
      route: route.geometry,
      maneuvers: route.maneuvers,
      nextIndex: nextIndex,
      remainingMeters: _remainingDistance(route, position, distance),
      remainingSeconds: route.durationSeconds,
    );
  }

  double _remainingDistance(
    OsrmRoute route,
    LatLng position,
    Distance distance,
  ) {
    final geometry = route.geometry;
    if (geometry.isEmpty) return 0;
    if (geometry.length == 1) {
      return distance.as(LengthUnit.Meter, position, geometry.first);
    }

    var bestSegment = 0;
    var bestScore = double.infinity;

    for (var i = 0; i < geometry.length - 1; i++) {
      final startDistance = distance.as(
        LengthUnit.Meter,
        position,
        geometry[i],
      );
      final endDistance = distance.as(
        LengthUnit.Meter,
        position,
        geometry[i + 1],
      );
      final score = startDistance + endDistance;
      if (score < bestScore) {
        bestScore = score;
        bestSegment = i;
      }
    }

    final start = geometry[bestSegment];
    final end = geometry[bestSegment + 1];
    final segmentLength = distance.as(LengthUnit.Meter, start, end);
    if (segmentLength <= 0) return 0;

    final toStart = distance.as(LengthUnit.Meter, position, start);
    final toEnd = distance.as(LengthUnit.Meter, position, end);

    // Estimate the vehicle's progress along the closest route segment.
    // For a point on the segment, dStart / (dStart + dEnd) is the
    // travelled fraction and avoids counting the full segment twice.
    final fraction = (toStart / (toStart + toEnd)).clamp(0.0, 1.0);
    var remaining = segmentLength * (1 - fraction);

    for (var i = bestSegment + 1; i < geometry.length - 1; i++) {
      remaining += distance.as(
        LengthUnit.Meter,
        geometry[i],
        geometry[i + 1],
      );
    }

    return remaining;
  }
}
