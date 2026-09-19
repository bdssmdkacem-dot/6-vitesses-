import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/driving/performance_metrics.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  test('measures 0-60 and 0-100 crossings and peak values', () {
    final metrics = PerformanceMetrics();
    metrics.reset(t0);
    metrics.addSample(speedKmh: 0, longitudinalAcceleration: 0, lateralAcceleration: 0, timestamp: t0);
    metrics.addSample(speedKmh: 30, longitudinalAcceleration: 2, lateralAcceleration: 1, timestamp: t0.add(const Duration(seconds: 1)));
    metrics.addSample(speedKmh: 60, longitudinalAcceleration: 3, lateralAcceleration: 2, timestamp: t0.add(const Duration(seconds: 2)));
    metrics.addSample(speedKmh: 110, longitudinalAcceleration: 4, lateralAcceleration: 3, timestamp: t0.add(const Duration(seconds: 4)));
    metrics.addSample(speedKmh: 80, longitudinalAcceleration: -5, lateralAcceleration: -4, timestamp: t0.add(const Duration(seconds: 5)));
    final s = metrics.snapshot(t0.add(const Duration(seconds: 6)));
    expect(s.zeroToSixtySeconds, 2);
    expect(s.zeroToHundredSeconds, 4);
    expect(s.maxSpeedKmh, 110);
    expect(s.maxAcceleration, 4);
    expect(s.maxBraking, -5);
    expect(s.maxLateralG, closeTo(4 / 9.80665, 0.0001));
  });

  test('a new stop starts a fresh acceleration run', () {
    final metrics = PerformanceMetrics();
    metrics.reset(t0);
    metrics.addSample(speedKmh: 0, longitudinalAcceleration: 0, lateralAcceleration: 0, timestamp: t0);
    metrics.addSample(speedKmh: 70, longitudinalAcceleration: 2, lateralAcceleration: 0, timestamp: t0.add(const Duration(seconds: 3)));
    metrics.addSample(speedKmh: 0, longitudinalAcceleration: -3, lateralAcceleration: 0, timestamp: t0.add(const Duration(seconds: 5)));
    metrics.addSample(speedKmh: 65, longitudinalAcceleration: 2, lateralAcceleration: 0, timestamp: t0.add(const Duration(seconds: 8)));
    expect(metrics.snapshot(t0.add(const Duration(seconds: 9))).zeroToSixtySeconds, 3);
  });
}
