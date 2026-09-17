import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/sensors/gps_speed_service.dart';

void main() {
  test('stale is true before first GPS update', () {
    final service = GpsSpeedService();
    expect(service.isStale, isTrue);
    service.dispose();
  });

  test('configuration is retained', () {
    final service = GpsSpeedService(windowSize: 7, maxAccuracyMeters: 30);
    expect(service.windowSize, 7);
    expect(service.maxAccuracyMeters, 30);
    service.dispose();
  });
}
