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
