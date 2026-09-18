import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../lib/features/navigation/navigation_models.dart';
import '../lib/features/navigation/navigation_session_controller.dart';
import '../lib/features/navigation/osrm_route_service.dart';

OsrmRoute route() => OsrmRoute(
  geometry: const [LatLng(0, 0), LatLng(0, 0.01)],
  distanceMeters: 1000,
  durationSeconds: 60,
  maneuvers: const [
    NavigationManeuver(
      type: NavigationManeuverType.straight,
      position: LatLng(0, 0.005),
      distanceMeters: 500,
    ),
    NavigationManeuver(
      type: NavigationManeuverType.arrive,
      position: LatLng(0, 0.01),
      distanceMeters: 0,
    ),
  ],
  start: const LatLng(0, 0),
  destination: const LatLng(0, 0.01),
);

NavigationState state({bool offRoute = false, double remaining = 500}) =>
    NavigationState(
      route: route().geometry,
      maneuvers: route().maneuvers,
      nextIndex: 0,
      remainingMeters: remaining,
      remainingSeconds: remaining / 10,
      distanceFromRouteMeters: offRoute ? 50 : 2,
      offRoute: offRoute,
      routeProgressMeters: 1000 - remaining,
      routeTotalMeters: 1000,
    );

void main() {
  test('starts in navigating state', () {
    final controller = NavigationSessionController();
    controller.start(route());
    expect(controller.status, NavigationSessionStatus.navigating);
  });

  test('requires sustained off-route state before rerouting', () {
    final controller = NavigationSessionController();
    controller.start(route());
    final t0 = DateTime(2026, 1, 1, 12);
    controller.update(state(offRoute: true), t0);
    expect(controller.status, NavigationSessionStatus.navigating);
    controller.update(state(offRoute: true), t0.add(const Duration(seconds: 4)));
    expect(controller.status, NavigationSessionStatus.offRoute);
    expect(controller.shouldReroute(t0.add(const Duration(seconds: 4))), isTrue);
  });

  test('reroute cooldown prevents immediate retry', () {
    final controller = NavigationSessionController();
    controller.start(route());
    final t0 = DateTime(2026, 1, 1, 12);
    controller.update(state(offRoute: true), t0);
    controller.update(state(offRoute: true), t0.add(const Duration(seconds: 4)));
    controller.beginReroute(t0.add(const Duration(seconds: 4)));
    controller.rerouteFailed();
    expect(controller.shouldReroute(t0.add(const Duration(seconds: 5))), isFalse);
    expect(controller.shouldReroute(t0.add(const Duration(seconds: 24))), isTrue);
  });

  test('arrival transitions to arrived', () {
    final controller = NavigationSessionController();
    controller.start(route());
    controller.update(state(remaining: 5), DateTime(2026, 1, 1, 12));
    expect(controller.status, NavigationSessionStatus.arrived);
  });
}
