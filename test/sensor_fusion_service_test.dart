import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:six_vitesses/features/sensors/gps_speed_service.dart';
import 'package:six_vitesses/features/sensors/motion_sensor_service.dart';
import 'package:six_vitesses/features/sensors/sensor_fusion_service.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  test('fused source combines fresh GPS and IMU confidence', () {
    final fusion = SensorFusionService();
    fusion.updateMotion(MotionSample(
      longitudinalAcceleration: 1.2,
      lateralAcceleration: 0.1,
      totalAcceleration: 1.3,
      timestamp: t0,
      axis: 0,
      noiseConfidence: 0.9,
    ));
    final sample = fusion.updateGps(GpsSample(
      speedKmh: 50,
      accuracyM: 5,
      longitudinalAcceleration: 1.0,
      timestamp: t0,
      isStale: false,
      position: LatLng(34.02, -6.84),
      speedConfidence: 0.95,
    ));
    expect(sample.source, SensorSource.fused);
    expect(sample.speedKmh, 50);
    expect(sample.overallConfidence, greaterThan(.5));
  });

  test('IMU briefly bridges a stale GPS stream without unbounded drift', () {
    final fusion = SensorFusionService(gpsFreshness: const Duration(seconds: 1));
    fusion.updateGps(GpsSample(
      speedKmh: 60,
      accuracyM: 6,
      longitudinalAcceleration: 0,
      timestamp: t0,
      isStale: false,
      speedConfidence: .9,
    ));
    fusion.updateMotion(MotionSample(
      longitudinalAcceleration: 1,
      lateralAcceleration: 0,
      totalAcceleration: 1,
      timestamp: t0.add(const Duration(milliseconds: 1200)),
      axis: 0,
      noiseConfidence: .9,
    ));
    final sample = fusion.current(t0.add(const Duration(milliseconds: 1400)));
    expect(sample.source, SensorSource.imu);
    expect(sample.speedKmh, closeTo(65.04, .2));
  });
}
