import 'dart:math' as math;

import 'gps_speed_service.dart';
import 'motion_sensor_service.dart';
import '../driving/obd/obd_telemetry.dart';

enum SensorSource { unavailable, gps, imu, obd, fused }

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
    this.obdFreshness = const Duration(seconds: 2),
  });

  final Duration gpsFreshness;
  final Duration imuFreshness;
  final Duration imuSpeedHold;
  final Duration obdFreshness;

  GpsSample? _gps;
  MotionSample? _motion;
  ObdTelemetry? _obd;
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

  SensorFusionSample updateObd(ObdTelemetry sample, [DateTime? timestamp]) {
    _obd = sample;
    return _compose(timestamp ?? sample.timestamp ?? DateTime.now());
  }

  // OBD-II is intentionally disabled in the active fusion path.
  // GPS + IMU are the only authoritative runtime sources for now.
  bool obdIsFresh(DateTime now) => false;

  SensorFusionSample current([DateTime? now]) =>
      _compose(now ?? DateTime.now());

  SensorFusionSample _compose(DateTime now) {
    final previousComposeAt = _lastFusionAt;
    _lastFusionAt = now;

    final gps = _gps;
    final motion = _motion;

    final gpsAge = gps == null
        ? const Duration(days: 1)
        : now.difference(gps.timestamp).abs();
    final imuAge = motion == null
        ? const Duration(days: 1)
        : now.difference(motion.timestamp).abs();

    final gpsFresh =
        gps != null && !gps.isStale && gpsAge <= gpsFreshness;
    final imuFresh = motion != null && imuAge <= imuFreshness;

    var speed = _fusedSpeed;
    var source = SensorSource.unavailable;
    var speedConfidence = 0.0;

    // Active speed source: GPS first. IMU may only propagate a recent
    // GPS speed for a short hold window; it never depends on OBD.
    if (gpsFresh) {
      speed = gps.speedKmh;
      _fusedSpeed = speed;
      _fusedSpeedAt = gps.timestamp;
      source = imuFresh ? SensorSource.fused : SensorSource.gps;
      speedConfidence = gps.speedConfidence;
    } else if (imuFresh && motion != null) {
      final fusedSpeedAt = _fusedSpeedAt;
      if (fusedSpeedAt != null) {
        final sinceSpeed = now.difference(fusedSpeedAt);
        if (sinceSpeed <= imuSpeedHold) {
          final dt = previousComposeAt == null
              ? 0.0
              : now.difference(previousComposeAt).inMilliseconds / 1000.0;
          speed = (_fusedSpeed +
                  motion.longitudinalAcceleration * dt * 3.6)
              .clamp(0.0, 400.0)
              .toDouble();
          _fusedSpeed = speed;
          source = SensorSource.imu;
          speedConfidence = (motion.noiseConfidence *
                  (1.0 -
                      sinceSpeed.inMilliseconds /
                          imuSpeedHold.inMilliseconds))
              .clamp(0.0, 1.0)
              .toDouble();
        } else {
          speed = 0;
          source = SensorSource.imu;
        }
      } else {
        speed = 0;
        source = SensorSource.imu;
      }
    }

    final gpsAccel = gpsFresh ? gps.longitudinalAcceleration : null;
    final imuAccel = imuFresh ? motion.longitudinalAcceleration : null;

    final gpsConfidence = gps?.speedConfidence ?? 0.0;
    final imuConfidence = motion?.noiseConfidence ?? 0.0;

    double acceleration;
    if (gpsAccel != null && imuAccel != null) {
      final wg = gpsConfidence.clamp(.15, 1.0);
      final wi = imuConfidence.clamp(.15, 1.0);
      acceleration = (gpsAccel * wg + imuAccel * wi) / (wg + wi);
    } else {
      acceleration = imuAccel ?? gpsAccel ?? 0;
    }

    final accelerationConfidence = imuFresh
        ? imuConfidence
        : (gpsFresh ? gpsConfidence * .75 : 0.0);

    final overall = math.sqrt(speedConfidence * accelerationConfidence)
        .clamp(0.0, 1.0)
        .toDouble();

    if (!gpsFresh && !imuFresh) {
      if (_fusedSpeedAt != null && speed > 0) {
        source = SensorSource.gps;
      } else {
        source = SensorSource.unavailable;
      }
    } else if (source == SensorSource.fused && overall < .25) {
      source = SensorSource.gps;
    }

    return SensorFusionSample(
      speedKmh: speed,
      longitudinalAcceleration:
          acceleration.clamp(-15.0, 15.0).toDouble(),
      lateralAcceleration: imuFresh ? motion.lateralAcceleration : 0,
      totalAcceleration: imuFresh ? motion.totalAcceleration : 0,
      speedConfidence: speedConfidence,
      accelerationConfidence: accelerationConfidence,
      overallConfidence: overall,
      source: source,
      timestamp: now,
    );
  }
}
