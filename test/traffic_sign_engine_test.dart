import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:six_vitesses/features/navigation/traffic_sign_engine.dart';

void main() {
  test('returns signs ahead and orders them by distance', () {
    final engine = TrafficSignEngine();
    final signs = [
      TrafficSign(type: TrafficSignType.stop, position: LatLng(34.0215, -6.8416)),
      TrafficSign(type: TrafficSignType.giveWay, position: LatLng(34.0250, -6.8416)),
    ];
    final result = engine.findRelevant(
      vehiclePosition: const LatLng(34.0200, -6.8416),
      headingDegrees: 0,
      vehicleSpeedKmh: 30,
      signs: signs,
    );
    expect(result, hasLength(2));
    expect(result.first.sign.type, TrafficSignType.stop);
  });

  test('ignores signs behind the vehicle when heading is reliable', () {
    final engine = TrafficSignEngine();
    final result = engine.findRelevant(
      vehiclePosition: const LatLng(34.0200, -6.8416),
      headingDegrees: 0,
      vehicleSpeedKmh: 30,
      signs: const [
        TrafficSign(type: TrafficSignType.stop, position: LatLng(34.0180, -6.8416)),
      ],
    );
    expect(result, isEmpty);
  });

  test('maps common OSM sign values', () {
    expect(trafficSignTypeFromOsm('stop'), TrafficSignType.stop);
    expect(trafficSignTypeFromOsm('give_way'), TrafficSignType.giveWay);
    expect(trafficSignTypeFromOsm('maxspeed'), TrafficSignType.speedLimit);
  });

  test('associates signs with the active route and rejects a parallel road', () {
    final engine = TrafficSignEngine(routeToleranceMeters: 45);
    const route = [
      LatLng(34.0200, -6.8416),
      LatLng(34.0250, -6.8416),
    ];
    final result = engine.findRelevant(
      vehiclePosition: const LatLng(34.0210, -6.8416),
      headingDegrees: 0,
      vehicleSpeedKmh: 40,
      vehicleRouteProgressMeters: 100,
      route: route,
      signs: const [
        TrafficSign(
          type: TrafficSignType.speedLimit,
          position: LatLng(34.0220, -6.8416),
          value: 50,
          directionDegrees: 0,
        ),
        TrafficSign(
          type: TrafficSignType.speedLimit,
          position: LatLng(34.0220, -6.8430),
          value: 30,
          directionDegrees: 0,
        ),
      ],
    );
    expect(result, hasLength(1));
    expect(result.single.sign.value, 50);
  });

  test('rejects crossing-road signs when route direction is incompatible', () {
    final engine = TrafficSignEngine();
    final result = engine.findRelevant(
      vehiclePosition: const LatLng(34.0200, -6.8416),
      headingDegrees: 0,
      vehicleSpeedKmh: 40,
      route: const [
        LatLng(34.0200, -6.8416),
        LatLng(34.0250, -6.8416),
      ],
      signs: const [
        TrafficSign(
          type: TrafficSignType.trafficSignals,
          position: LatLng(34.0208, -6.8410),
          directionDegrees: 90,
        ),
      ],
    );
    expect(result, isEmpty);
  });

  test('activeSpeedLimit reports the most recently passed maxspeed sign', () {
    final engine = TrafficSignEngine();
    const route = [
      LatLng(34.0200, -6.8416),
      LatLng(34.0400, -6.8416),
    ];
    final limit = engine.activeSpeedLimit(
      route: route,
      vehicleRouteProgressMeters: 1200,
      signs: const [
        // Passed already (behind current progress) — should be reported.
        TrafficSign(type: TrafficSignType.speedLimit, position: LatLng(34.0210, -6.8416), value: 50),
        // Even further behind — the closer/most recent one wins.
        TrafficSign(type: TrafficSignType.speedLimit, position: LatLng(34.0205, -6.8416), value: 30),
        // Still ahead — must not be reported as active yet.
        TrafficSign(type: TrafficSignType.speedLimit, position: LatLng(34.0390, -6.8416), value: 90),
      ],
    );
    expect(limit, 50);
  });

  test('activeSpeedLimit returns null with no route context', () {
    final engine = TrafficSignEngine();
    final limit = engine.activeSpeedLimit(
      route: const [],
      vehicleRouteProgressMeters: 100,
      signs: const [
        TrafficSign(type: TrafficSignType.speedLimit, position: LatLng(34.0210, -6.8416), value: 50),
      ],
    );
    expect(limit, isNull);
  });

  test('keeps roundabout signs ahead on the active route', () {
    final engine = TrafficSignEngine();
    final result = engine.findRelevant(
      vehiclePosition: const LatLng(34.0200, -6.8416),
      headingDegrees: 0,
      vehicleSpeedKmh: 35,
      route: const [
        LatLng(34.0200, -6.8416),
        LatLng(34.0250, -6.8416),
      ],
      vehicleRouteProgressMeters: 0,
      signs: const [
        TrafficSign(
          type: TrafficSignType.roundabout,
          position: LatLng(34.0230, -6.8416),
        ),
      ],
    );
    expect(result.single.sign.type, TrafficSignType.roundabout);
  });
}
