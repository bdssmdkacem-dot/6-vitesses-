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
  DateTime? _launchStart;
  DateTime? _lastAt;
  double _previousSpeed = 0;
  double _maxSpeed = 0;
  double _maxAcceleration = 0;
  double _maxBraking = 0;
  double _maxLateralG = 0;
  double _distanceKm = 0;
  double _speedSum = 0;
  int _samples = 0;
  double? _zeroToSixty;
  double? _zeroToHundred;
  bool _launchArmed = false;

  void reset(DateTime startedAt) {
    _start = startedAt;
    _launchStart = null;
    _lastAt = null;
    _previousSpeed = 0;
    _maxSpeed = 0;
    _maxAcceleration = 0;
    _maxBraking = 0;
    _maxLateralG = 0;
    _distanceKm = 0;
    _speedSum = 0;
    _samples = 0;
    _zeroToSixty = null;
    _zeroToHundred = null;
    _launchArmed = false;
  }

  void addSample({
    required double speedKmh,
    required double longitudinalAcceleration,
    required double lateralAcceleration,
    required DateTime timestamp,
  }) {
    if (_start == null) reset(timestamp);

    final speed = speedKmh.clamp(0.0, 400.0).toDouble();
    final previousAt = _lastAt;
    if (previousAt != null) {
      final dt = timestamp.difference(previousAt).inMilliseconds / 1000.0;
      if (dt > 0 && dt <= 10) {
        _distanceKm += speed * dt / 3600.0;
      }
    }

    _lastAt = timestamp;
    _samples++;
    _speedSum += speed;
    _maxSpeed = math.max(_maxSpeed, speed);
    _maxAcceleration = math.max(_maxAcceleration, longitudinalAcceleration);
    _maxBraking = math.min(_maxBraking, longitudinalAcceleration);
    _maxLateralG = math.max(
      _maxLateralG,
      lateralAcceleration.abs() / 9.80665,
    );

    // A launch attempt is armed at rest. Completed 0-60/0-100 values are
    // intentionally preserved; reaching 0 km/h later must not erase history.
    if (speed <= 2) {
      _launchStart = timestamp;
      _launchArmed = true;
    } else if (_launchArmed && _launchStart != null) {
      final previous = _previousSpeed;
      if (previous < 60 && speed >= 60) {
        final elapsed = _crossingElapsed(
          threshold: 60,
          previousSpeed: previous,
          currentSpeed: speed,
          previousAt: previousAt ?? timestamp,
          currentAt: timestamp,
          launchAt: _launchStart!,
        );
        _zeroToSixty = _minValid(_zeroToSixty, elapsed);
      }
      if (previous < 100 && speed >= 100) {
        final elapsed = _crossingElapsed(
          threshold: 100,
          previousSpeed: previous,
          currentSpeed: speed,
          previousAt: previousAt ?? timestamp,
          currentAt: timestamp,
          launchAt: _launchStart!,
        );
        _zeroToHundred = _minValid(_zeroToHundred, elapsed);
      }
      if (_zeroToHundred != null && _zeroToSixty != null) {
        // Keep the attempt armed for possible better runs after another stop.
      }
    }

    _previousSpeed = speed;
  }

  double _crossingElapsed({
    required double threshold,
    required double previousSpeed,
    required double currentSpeed,
    required DateTime previousAt,
    required DateTime currentAt,
    required DateTime launchAt,
  }) {
    final totalSeconds =
        currentAt.difference(launchAt).inMilliseconds / 1000.0;
    if (totalSeconds < 0 || totalSeconds > 120) return double.infinity;

    final delta = currentSpeed - previousSpeed;
    if (delta <= 0) return totalSeconds;

    final fraction = ((threshold - previousSpeed) / delta).clamp(0.0, 1.0);
    final sampleSeconds =
        currentAt.difference(previousAt).inMilliseconds / 1000.0;
    return math.max(0, totalSeconds - sampleSeconds * (1 - fraction));
  }

  double? _minValid(double? current, double candidate) {
    if (!candidate.isFinite || candidate < 0.2 || candidate > 120) {
      return current;
    }
    return current == null ? candidate : math.min(current, candidate);
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
        durationSeconds:
            _start == null ? 0 : now.difference(_start!).inSeconds,
      );
}
