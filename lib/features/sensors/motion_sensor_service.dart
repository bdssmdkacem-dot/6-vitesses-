import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class MotionSample {
  const MotionSample({
    required this.totalAcceleration,
    required this.timestamp,
  });
  final double totalAcceleration;
  final DateTime timestamp;
}

class MotionSensorService {
  MotionSensorService({
    this.samplingPeriod = const Duration(milliseconds: 100),
  });

  final Duration samplingPeriod;
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final _controller = StreamController<MotionSample>.broadcast();

  Stream<MotionSample> get samples => _controller.stream;

  void start() {
    _subscription = userAccelerometerEventStream(
      samplingPeriod: samplingPeriod,
    ).listen((event) {
      final magnitude = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _controller.add(MotionSample(
        totalAcceleration: magnitude,
        timestamp: DateTime.now(),
      ));
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
