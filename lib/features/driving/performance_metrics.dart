import 'dart:math' as math;

class PerformanceSnapshot {
  const PerformanceSnapshot({
    required this.zeroToSixtySeconds,
    required this.zeroToHundredSeconds,
    required this.maxSpeedKmh,
    required this.maxAcceleration,
    required this.maxBraking,
    required this.maxLateralG,
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.durationSeconds,
  });

  final double? zeroToSixtySeconds;
  final double? zeroToHundredSeconds;
  final double maxSpeedKmh;
  final double maxAcceleration;
  final double maxBraking;
  final double maxLateralG;
  final double distanceKm;
  final double averageSpeedKmh;
  final int durationSeconds;
}

class PerformanceMetrics {
  DateTime? _start;
  DateTime? _zeroStart;
  double _maxSpeed = 0;
  double _maxAcceleration = 0;
  double _maxBraking = 0;
  double _maxLateralG = 0;
  double _distanceKm = 0;
  double _speedSum = 0;
  int _samples = 0;
  double? _zeroToSixty;
  double? _zeroToHundred;
  DateTime? _lastAt;

  void reset(DateTime startedAt) {
    _start = startedAt;
    _zeroStart = null;
    _maxSpeed = 0;
    _maxAcceleration = 0;
    _maxBraking = 0;
    _maxLateralG = 0;
    _distanceKm = 0;
    _speedSum = 0;
    _samples = 0;
    _zeroToSixty = null;
    _zeroToHundred = null;
    _lastAt = null;
  }

  void addSample({
    required double speedKmh,
    required double longitudinalAcceleration,
    required double lateralAcceleration,
    required DateTime timestamp,
  }) {
    if (_start == null) reset(timestamp);
    if (_lastAt != null) {
      final dt = timestamp.difference(_lastAt!).inMilliseconds / 1000.0;
      if (dt > 0 && dt <= 2) _distanceKm += speedKmh * dt / 3600.0;
    }
    _lastAt = timestamp;
    _samples++;
    _speedSum += speedKmh;
    _maxSpeed = math.max(_maxSpeed, speedKmh);
    _maxAcceleration = math.max(_maxAcceleration, longitudinalAcceleration);
    _maxBraking = math.min(_maxBraking, longitudinalAcceleration);
    _maxLateralG = math.max(_maxLateralG, lateralAcceleration.abs() / 9.80665);

    if (speedKmh <= 2 && _zeroStart == null) {
      _zeroStart = timestamp;
    } else if (_zeroStart != null && speedKmh > 2) {
      _zeroStart = _zeroStart;
      final elapsed = timestamp.difference(_zeroStart!).inMilliseconds / 1000.0;
      if (_zeroToSixty == null && speedKmh >= 60 && elapsed >= 0.2 && elapsed <= 120) {
        _zeroToSixty = elapsed;
      }
      if (_zeroToHundred == null && speedKmh >= 100 && elapsed >= 0.2 && elapsed <= 120) {
        _zeroToHundred = elapsed;
      }
    }
  }

  PerformanceSnapshot snapshot(DateTime now) => PerformanceSnapshot(
    zeroToSixtySeconds: _zeroToSixty,
    zeroToHundredSeconds: _zeroToHundred,
    maxSpeedKmh: _maxSpeed,
    maxAcceleration: _maxAcceleration,
    maxBraking: _maxBraking,
    maxLateralG: _maxLateralG,
    distanceKm: _distanceKm,
    averageSpeedKmh: _samples == 0 ? 0 : _speedSum / _samples,
    durationSeconds: _start == null ? 0 : now.difference(_start!).inSeconds,
  );
}
