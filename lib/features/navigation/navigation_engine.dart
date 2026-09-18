import 'package:latlong2/latlong.dart';
import 'navigation_models.dart';
import 'osrm_route_service.dart';

class NavigationEngine {
  const NavigationEngine();

  NavigationState update({required OsrmRoute route, required LatLng position}) {
    final distance = const Distance();
    var nearestIndex = 0;
    var nearestMeters = double.infinity;
    for (var i = 0; i < route.maneuvers.length; i++) {
      final meters = distance.as(LengthUnit.Meter, position, route.maneuvers[i].position);
      if (meters < nearestMeters) { nearestMeters = meters; nearestIndex = i; }
    }
    var nextIndex = route.maneuvers.isEmpty ? -1 : nearestIndex;
    if (nextIndex >= 0) {
      while (nextIndex < route.maneuvers.length - 1 &&
          distance.as(LengthUnit.Meter, position, route.maneuvers[nextIndex].position) < 18) {
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

  double _remainingDistance(OsrmRoute route, LatLng position, Distance distance) {
    if (route.geometry.isEmpty) return 0;
    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < route.geometry.length; i++) {
      final d = distance.as(LengthUnit.Meter, position, route.geometry[i]);
      if (d < best) { best = d; nearest = i; }
    }
    var result = best;
    for (var i = nearest; i < route.geometry.length - 1; i++) {
      result += distance.as(LengthUnit.Meter, route.geometry[i], route.geometry[i + 1]);
    }
    return result;
  }
}
