import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/driving/performance_metrics.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  test('measures interpolated 0-60 and 0-100 crossings and peak values', () {
    final metrics = PerformanceMetrics();
    metrics.reset(t0);
    metrics.addSample(
      speedKmh: 0,
      longitudinalAcceleration: 0,
      lateralAcceleration: 0,
      timestamp: t0,
    );
    metrics.addSample(
      speedKmh: 30,
      longitudinalAcceleration: 2,
      lateralAcceleration: 1,
      timestamp: t0.add(const Duration(seconds: 1)),
    );
    metrics.addSample(
      speedKmh: 60,
      longitudinalAcceleration: 3,
      lateralAcceleration: 2,
      timestamp: t0.add(const Duration(seconds: 2)),
    );
    metrics.addSample(
      speedKmh: 110,
      longitudinalAcceleration: 4,
      lateralAcceleration: 3,
      timestamp: t0.add(const Duration(seconds: 4)),
    );
    metrics.addSample(
      speedKmh: 80,
      longitudinalAcceleration: -5,
      lateralAcceleration: -4,
      timestamp: t0.add(const Duration(seconds: 5)),
    );
    final s = metrics.snapshot(t0.add(const Duration(seconds: 6)));

    expect(s.zeroToSixtySeconds, closeTo(2, 0.001));
    expect(s.zeroToHundredSeconds, closeTo(3.6, 0.001));
    expect(s.maxSpeedKmh, 110);
    expect(s.maxAcceleration, 4);
    expect(s.maxBraking, -5);
    expect(s.maxLateralG, closeTo(4 / 9.80665, 0.0001));
  });

  test('completed acceleration times survive a later stop', () {
    final metrics = PerformanceMetrics();
    metrics.reset(t0);
    metrics.addSample(
      speedKmh: 0,
      longitudinalAcceleration: 0,
      timestamp: t0,
      lateralAcceleration: 0,
    );
    metrics.addSample(
      speedKmh: 70,
      longitudinalAcceleration: 2,
      timestamp: t0.add(const Duration(seconds: 3)),
      lateralAcceleration: 0,
    );
    metrics.addSample(
      speedKmh: 0,
      longitudinalAcceleration: -3,
      timestamp: t0.add(const Duration(seconds: 5)),
      lateralAcceleration: 0,
    );
    final snapshot = metrics.snapshot(t0.add(const Duration(seconds: 6)));
    expect(snapshot.zeroToSixtySeconds, closeTo(3 - (10 / 70) * 3, 0.01));
  });

  test('a later launch can improve the recorded best time', () {
    final metrics = PerformanceMetrics();
    metrics.reset(t0);
    metrics.addSample(
      speedKmh: 0,
      longitudinalAcceleration: 0,
      lateralAcceleration: 0,
      timestamp: t0,
    );
    metrics.addSample(
      speedKmh: 70,
      longitudinalAcceleration: 2,
      lateralAcceleration: 0,
      timestamp: t0.add(const Duration(seconds: 4)),
    );
    metrics.addSample(
      speedKmh: 0,
      longitudinalAcceleration: -3,
      lateralAcceleration: 0,
      timestamp: t0.add(const Duration(seconds: 5)),
    );
    metrics.addSample(
      speedKmh: 70,
      longitudinalAcceleration: 3,
      lateralAcceleration: 0,
      timestamp: t0.add(const Duration(seconds: 7)),
    );
    expect(metrics.snapshot(t0.add(const Duration(seconds: 8))).zeroToSixtySeconds,
        closeTo(2 - (10 / 70) * 2, 0.01));
  });
}
