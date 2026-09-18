import 'package:latlong2/latlong.dart';

enum NavigationManeuverType { depart, arrive, turnLeft, turnRight, sharpLeft, sharpRight, uTurn, straight, roundabout, merge, fork, offRamp, onRamp, endOfRoad, unknown }

class NavigationManeuver {
  const NavigationManeuver({required this.type, required this.position, required this.distanceMeters, this.name, this.modifier, this.exitNumber});
  final NavigationManeuverType type;
  final LatLng position;
  final double distanceMeters;
  final String? name;
  final String? modifier;
  final int? exitNumber;
}

class NavigationState {
  const NavigationState({
    required this.route,
    required this.maneuvers,
    required this.nextIndex,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.distanceFromRouteMeters,
    required this.offRoute,
    this.routeBearingDegrees = 0,
    this.nextManeuverDistanceMeters = 0,
    this.routeProgressMeters = 0,
    this.routeTotalMeters = 0,
  });
  final List<LatLng> route;
  final List<NavigationManeuver> maneuvers;
  final int nextIndex;
  final double remainingMeters;
  final double remainingSeconds;
  final double distanceFromRouteMeters;
  final bool offRoute;
  final double routeBearingDegrees;
  final double nextManeuverDistanceMeters;
  final double routeProgressMeters;
  final double routeTotalMeters;
  NavigationManeuver? get nextManeuver => nextIndex >= 0 && nextIndex < maneuvers.length ? maneuvers[nextIndex] : null;
  bool get arrived => nextManeuver?.type == NavigationManeuverType.arrive;
}
