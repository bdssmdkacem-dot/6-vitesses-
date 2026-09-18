import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class MotionSample {
  const MotionSample({
    required this.longitudinalAcceleration,
    required this.lateralAcceleration,
    required this.totalAcceleration,
    required this.timestamp,
    required this.axis,
  });

  final double longitudinalAcceleration;
  final double lateralAcceleration;
  final double totalAcceleration;
  final DateTime timestamp;
  final int axis;
}

class MotionSensorService {
  MotionSensorService({
    this.samplingPeriod = const Duration(milliseconds: 20),
  });

  final Duration samplingPeriod;
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final _controller = StreamController<MotionSample>.broadcast();

  Stream<MotionSample> get samples => _controller.stream;

  int _axis = 0;
  double _sign = 1.0;
  bool _calibrated = false;
  double _filteredX = 0;
  double _filteredY = 0;
  double _filteredZ = 0;
  double _previousSpeedKmh = 0;
  DateTime? _previousSpeedTime;
  double _axisScoreX = 0;
  double _axisScoreY = 0;
  double _speedDerivativeFilter = 0;

  void start() {
    if (_subscription != null) return;
    _subscription = userAccelerometerEventStream(
      samplingPeriod: samplingPeriod,
    ).listen((event) {
      const alpha = 0.22;
      _filteredX += alpha * (event.x - _filteredX);
      _filteredY += alpha * (event.y - _filteredY);
      _filteredZ += alpha * (event.z - _filteredZ);

      final x = _filteredX;
      final y = _filteredY;
      final z = _filteredZ;
      final total = math.sqrt(x * x + y * y + z * z);

      if (!_calibrated && _speedDerivativeFilter.abs() > 0.35) {
        _axisScoreX = _axisScoreX * 0.98 + x.abs() * _speedDerivativeFilter.abs();
        _axisScoreY = _axisScoreY * 0.98 + y.abs() * _speedDerivativeFilter.abs();
        if ((_axisScoreX + _axisScoreY) > 3.0) {
          _axis = _axisScoreX >= _axisScoreY ? 0 : 1;
          final candidate = _axis == 0 ? x : y;
          if (candidate.abs() > 0.25) {
            _sign = candidate.sign == _speedDerivativeFilter.sign ? 1.0 : -1.0;
            _calibrated = true;
          }
        }
      }

      final longitudinal = _slewAndClamp((_axis == 0 ? x : y) * _sign);
      final lateral = _slewAndClamp(_axis == 0 ? y : x);

      _controller.add(MotionSample(
        longitudinalAcceleration: longitudinal,
        lateralAcceleration: lateral,
        totalAcceleration: total,
        timestamp: DateTime.now(),
        axis: _axis,
      ));
    });
  }

  void updateVehicleSpeed(double speedKmh, DateTime timestamp) {
    final previousTime = _previousSpeedTime;
    if (previousTime != null) {
      final dt = timestamp.difference(previousTime).inMilliseconds / 1000.0;
      if (dt >= 0.05 && dt <= 2.0) {
        final derivative = ((speedKmh - _previousSpeedKmh) / dt) / 3.6;
        _speedDerivativeFilter =
            _speedDerivativeFilter * 0.75 + derivative * 0.25;
      }
    }
    _previousSpeedKmh = speedKmh;
    _previousSpeedTime = timestamp;
  }

  double _slewAndClamp(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    return value.clamp(-15.0, 15.0).toDouble();
  }

  void recalibrate() {
    _calibrated = false;
    _axisScoreX = 0;
    _axisScoreY = 0;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
