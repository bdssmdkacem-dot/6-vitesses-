import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

class MotionSample {
  const MotionSample({
    required this.longitudinalAcceleration,
    required this.totalAcceleration,
    required this.timestamp,
  });

  final double longitudinalAcceleration;
  final double totalAcceleration;
  final DateTime timestamp;
}

class MotionSensorService {
  MotionSensorService({
    this.samplingPeriod = const Duration(milliseconds: 50),
  });

  final Duration samplingPeriod;

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final _controller = StreamController<MotionSample>.broadcast();
  double _filteredLongitudinal = 0;

  Stream<MotionSample> get samples => _controller.stream;

  void start() {
    _subscription?.cancel();
    _filteredLongitudinal = 0;
    _subscription = userAccelerometerEventStream(
      samplingPeriod: samplingPeriod,
    ).listen((event) {
      // The app is locked to landscape. In the Android sensor coordinate
      // system the X axis is the screen's horizontal axis, which is the
      // vehicle longitudinal axis for a phone mounted flat on the dashboard.
      // User-accelerometer data already has gravity removed.
      final rawLongitudinal = event.x;

      // Light EMA: much faster than the GPS derivative while still removing
      // high-frequency sensor noise.
      _filteredLongitudinal =
          (_filteredLongitudinal * 0.25) + (rawLongitudinal * 0.75);

      final longitudinal = _filteredLongitudinal.abs() < 0.08
          ? 0.0
          : _filteredLongitudinal.clamp(-12.0, 12.0).toDouble();

      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      _controller.add(
        MotionSample(
          longitudinalAcceleration: longitudinal,
          totalAcceleration: magnitude,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
