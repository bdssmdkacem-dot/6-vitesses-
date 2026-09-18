import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:six_vitesses/features/navigation/traffic_sign_engine.dart';

void main() {
  test('returns signs ahead and orders them by distance', () {
    const engine = TrafficSignEngine();
    final signs = [
      TrafficSign(type: TrafficSignType.stop, position: LatLng(34.0215, -6.8416)),
      TrafficSign(type: TrafficSignType.giveWay, position: LatLng(34.0250, -6.8416)),
    ];
    final result = engine.findRelevant(
      vehiclePosition: const LatLng(34.0200, -6.8416),
      headingDegrees: 0,
      signs: signs,
    );
    expect(result, hasLength(2));
    expect(result.first.sign.type, TrafficSignType.stop);
  });

  test('ignores signs behind the vehicle', () {
    const engine = TrafficSignEngine();
    final result = engine.findRelevant(
      vehiclePosition: const LatLng(34.0200, -6.8416),
      headingDegrees: 0,
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
}
