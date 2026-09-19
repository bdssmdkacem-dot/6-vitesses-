import 'dart:math' as math;

import 'gps_speed_service.dart';
import 'motion_sensor_service.dart';

enum SensorSource { unavailable, gps, imu, fused }

class SensorFusionSample {
  const SensorFusionSample({
    required this.speedKmh,
    required this.longitudinalAcceleration,
    required this.lateralAcceleration,
    required this.totalAcceleration,
    required this.speedConfidence,
    required this.accelerationConfidence,
    required this.overallConfidence,
    required this.source,
    required this.timestamp,
  });

  final double speedKmh;
  final double longitudinalAcceleration;
  final double lateralAcceleration;
  final double totalAcceleration;
  final double speedConfidence;
  final double accelerationConfidence;
  final double overallConfidence;
  final SensorSource source;
  final DateTime timestamp;
}

class SensorFusionService {
  SensorFusionService({
    this.gpsFreshness = const Duration(seconds: 2),
    this.imuFreshness = const Duration(milliseconds: 700),
    this.imuSpeedHold = const Duration(milliseconds: 1500),
  });

  final Duration gpsFreshness;
  final Duration imuFreshness;
  final Duration imuSpeedHold;

  GpsSample? _gps;
  MotionSample? _motion;
  double _fusedSpeed = 0;
  DateTime? _fusedSpeedAt;
  DateTime? _lastFusionAt;

  SensorFusionSample updateGps(GpsSample sample) {
    if (!sample.isStale) {
      _gps = sample;
      _fusedSpeed = sample.speedKmh;
      _fusedSpeedAt = sample.timestamp;
    }
    return _compose(sample.timestamp);
  }

  SensorFusionSample updateMotion(MotionSample sample) {
    _motion = sample;
    return _compose(sample.timestamp);
  }

  SensorFusionSample current([DateTime? now]) =>
      _compose(now ?? DateTime.now());

  SensorFusionSample _compose(DateTime now) {
    final previousComposeAt = _lastFusionAt;
    _lastFusionAt = now;
    final gps = _gps;
    final motion = _motion;
    final gpsAge = gps == null ? const Duration(days: 1) : now.difference(gps.timestamp).abs();
    final imuAge = motion == null ? const Duration(days: 1) : now.difference(motion.timestamp).abs();
    final gpsSample = gps;
    final motionSample = motion;
    final gpsFresh = gpsSample != null && !gpsSample.isStale && gpsAge <= gpsFreshness;
    final imuFresh = motionSample != null && imuAge <= imuFreshness;

    var speed = _fusedSpeed;
    var source = SensorSource.unavailable;
    var speedConfidence = 0.0;

    if (gpsFresh) {
      speed = gpsSample.speedKmh;
      _fusedSpeed = speed;
      _fusedSpeedAt = gpsSample.timestamp;
      source = imuFresh ? SensorSource.fused : SensorSource.gps;
      speedConfidence = gpsSample.speedConfidence;
    } else if (motionSample != null && _fusedSpeedAt != null) {
      final fusedAt = _fusedSpeedAt;
      final sinceGps = now.difference(fusedAt);
      if (sinceGps <= imuSpeedHold) {
        final dt = previousComposeAt == null ? 0.0 : now.difference(previousComposeAt).inMilliseconds / 1000.0;
        speed = (_fusedSpeed + motionSample.longitudinalAcceleration * dt * 3.6)
            .clamp(0.0, 400.0)
            .toDouble();
        _fusedSpeed = speed;
        source = SensorSource.imu;
        speedConfidence = (motionSample.noiseConfidence *
                (1.0 - sinceGps.inMilliseconds / imuSpeedHold.inMilliseconds))
            .clamp(0.0, 1.0)
            .toDouble();
      }
    }

    final gpsAccel = gpsFresh ? gpsSample.longitudinalAcceleration : null;
    final imuAccel = imuFresh ? motionSample.longitudinalAcceleration : null;
    double acceleration = 0;
    if (gpsAccel != null && imuAccel != null) {
      final wg = (gpsSample?.speedConfidence ?? .15).clamp(.15, 1.0);
      final wi = (motionSample?.noiseConfidence ?? .15).clamp(.15, 1.0);
      acceleration = (gpsAccel * wg + imuAccel * wi) / (wg + wi);
    } else {
      acceleration = imuAccel ?? gpsAccel ?? 0;
    }

    final accelerationConfidence = imuFresh
        ? (motionSample?.noiseConfidence ?? 0.0)
        : (gpsFresh ? (gpsSample?.speedConfidence ?? 0.0) * .75 : 0.0);
    final overall = math.sqrt(speedConfidence * accelerationConfidence)
        .clamp(0.0, 1.0)
        .toDouble();

    if (!gpsFresh && !imuFresh) source = SensorSource.unavailable;
    if (source == SensorSource.fused && overall < .25) source = SensorSource.gps;

    return SensorFusionSample(
      speedKmh: speed,
      longitudinalAcceleration: acceleration.clamp(-15.0, 15.0).toDouble(),
      lateralAcceleration: imuFresh ? motionSample.lateralAcceleration : 0,
      totalAcceleration: imuFresh ? motionSample.totalAcceleration : 0,
      speedConfidence: speedConfidence,
      accelerationConfidence: accelerationConfidence,
      overallConfidence: overall,
      source: source,
      timestamp: now,
    );
  }
}
