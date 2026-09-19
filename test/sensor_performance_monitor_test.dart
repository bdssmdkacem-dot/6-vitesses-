import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/sensors/sensor_performance_monitor.dart';

void main() {
  test('performance monitor records callback workload', () {
    final monitor = SensorPerformanceMonitor();
    monitor.recordCallback(const Duration(microseconds: 100));
    monitor.recordCallback(const Duration(microseconds: 300));
    final stats = monitor.snapshot();
    expect(stats.events, 2);
    expect(stats.averageCallbackMicros, 200);
    expect(stats.maxCallbackMicros, 300);
  });
}
