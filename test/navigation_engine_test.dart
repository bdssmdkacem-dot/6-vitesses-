import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:six_vitesses/features/navigation/navigation_engine.dart';
import 'package:six_vitesses/features/navigation/navigation_models.dart';
import 'package:six_vitesses/features/navigation/osrm_route_service.dart';

void main() {
  test('navigation engine selects the next maneuver and remaining route', () {
    final route = OsrmRoute(
      geometry: const [
        LatLng(34.0, -6.0),
        LatLng(34.001, -6.0),
        LatLng(34.002, -6.0),
      ],
      distanceMeters: 222,
      durationSeconds: 60,
      maneuvers: const [
        NavigationManeuver(
          type: NavigationManeuverType.depart,
          position: LatLng(34.0, -6.0),
          distanceMeters: 0,
        ),
        NavigationManeuver(
          type: NavigationManeuverType.turnRight,
          position: LatLng(34.002, -6.0),
          distanceMeters: 111,
        ),
      ],
    );
    final state = const NavigationEngine().update(
      route: route,
      position: LatLng(34.0015, -6.0),
    );
    expect(state.nextManeuver?.type, NavigationManeuverType.turnRight);
    expect(state.remainingMeters, greaterThan(0));
    expect(state.remainingMeters, lessThan(120));
  });
}


  test('navigation engine preserves forward segment continuity on a parallel branch', () {
    final route = OsrmRoute(
      geometry: const [
        LatLng(34.0, -6.0),
        LatLng(34.001, -6.0),
        LatLng(34.002, -6.0),
        LatLng(34.003, -5.999),
      ],
      distanceMeters: 333,
      durationSeconds: 60,
      maneuvers: const [
        NavigationManeuver(
          type: NavigationManeuverType.depart,
          position: LatLng(34.0, -6.0),
          distanceMeters: 0,
        ),
        NavigationManeuver(
          type: NavigationManeuverType.turnRight,
          position: LatLng(34.003, -5.999),
          distanceMeters: 100,
        ),
      ],
    );
    const engine = NavigationEngine();
    final first = engine.update(
      route: route,
      position: const LatLng(34.0015, -6.0),
      speedKmh: 40,
      headingDegrees: 0,
    );
    final second = engine.update(
      route: route,
      position: const LatLng(34.0022, -5.99995),
      speedKmh: 40,
      headingDegrees: 0,
      previousRouteProgressMeters: first.routeProgressMeters,
      previousRouteSegmentIndex: first.routeSegmentIndex,
    );
    expect(second.routeProgressMeters, greaterThan(first.routeProgressMeters));
    expect(second.routeSegmentIndex, greaterThanOrEqualTo(first.routeSegmentIndex));
  });

  test('navigation engine reports roundabout exit metadata in the maneuver', () {
    final maneuver = const NavigationManeuver(
      type: NavigationManeuverType.roundabout,
      position: LatLng(34.002, -6.0),
      distanceMeters: 80,
      exitNumber: 3,
      bearingBefore: 90,
      bearingAfter: 180,
      roadRef: 'N1',
    );
    expect(maneuver.exitNumber, 3);
    expect(maneuver.bearingBefore, 90);
    expect(maneuver.bearingAfter, 180);
    expect(maneuver.roadRef, 'N1');
  });
}
