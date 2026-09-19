import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:six_vitesses/features/sensors/gps_speed_service.dart';

void main() {
  test('stale is true before first GPS update', () {
    final service = GpsSpeedService();
    expect(service.isStale, isTrue);
    service.dispose();
  });

  test('rejects an impossible GPS jump', () {
    final service = GpsSpeedService(maxJumpSpeedKmh: 320);
    final accepted = service.isPlausibleJump(
      previous: const LatLng(34.0000, -6.0000),
      current: const LatLng(34.0200, -6.0000),
      elapsed: const Duration(seconds: 1),
      previousAccuracy: 5,
      currentAccuracy: 5,
    );
    expect(accepted, isFalse);
    service.dispose();
  });

  test('accepts a normal GPS movement', () {
    final service = GpsSpeedService(maxJumpSpeedKmh: 320);
    final accepted = service.isPlausibleJump(
      previous: const LatLng(34.0000, -6.0000),
      current: const LatLng(34.0003, -6.0000),
      elapsed: const Duration(seconds: 1),
      previousAccuracy: 5,
      currentAccuracy: 5,
    );
    expect(accepted, isTrue);
    service.dispose();
  });

  test('configuration is retained', () {
    final service = GpsSpeedService(windowSize: 7, maxAccuracyMeters: 30);
    expect(service.windowSize, 7);
    expect(service.maxAccuracyMeters, 30);
    service.dispose();
  });
}
