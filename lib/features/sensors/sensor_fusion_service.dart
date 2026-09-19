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
      if (!obdIsFresh(sample.timestamp)) {
        _fusedSpeed = sample.speedKmh;
        _fusedSpeedAt = sample.timestamp;
      }
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

  bool obdIsFresh(DateTime now) {
    final obd = _obd;
    final timestamp = obd?.timestamp;
    return obd != null &&
        obd.available &&
        timestamp != null &&
        now.difference(timestamp).abs() <= obdFreshness;
  }

  SensorFusionSample current([DateTime? now]) =>
      _compose(now ?? DateTime.now());

  SensorFusionSample _compose(DateTime now) {
    final previousComposeAt = _lastFusionAt;
    _lastFusionAt = now;

    final gps = _gps;
    final motion = _motion;
    final obd = _obd;

    final gpsAge = gps == null
        ? const Duration(days: 1)
        : now.difference(gps.timestamp).abs();
    final imuAge = motion == null
        ? const Duration(days: 1)
        : now.difference(motion.timestamp).abs();

    final gpsFresh =
        gps != null && !gps.isStale && gpsAge <= gpsFreshness;
    final imuFresh = motion != null && imuAge <= imuFreshness;
    final obdFresh = obdIsFresh(now);

    var speed = _fusedSpeed;
    var source = SensorSource.unavailable;
    var speedConfidence = 0.0;

    // OBD is optional. When fresh, its vehicle speed is preferred because it
    // comes directly from the vehicle ECU. GPS remains the fallback.
    if (obdFresh) {
      speed = obd!.vehicleSpeedKmh!.clamp(0.0, 400.0).toDouble();
      _fusedSpeed = speed;
      _fusedSpeedAt = obd.timestamp;
      speedConfidence = 0.98;
      source = gpsFresh || imuFresh ? SensorSource.fused : SensorSource.obd;
    } else if (gpsFresh) {
      speed = gps!.speedKmh;
      _fusedSpeed = speed;
      _fusedSpeedAt = gps.timestamp;
      source = imuFresh ? SensorSource.fused : SensorSource.gps;
      speedConfidence = gps.speedConfidence;
    } else {
      final fusedSpeedAt = _fusedSpeedAt;
      if (motion != null && fusedSpeedAt != null) {
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
        }
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

    if (!gpsFresh && !imuFresh && !obdFresh) {
      source = SensorSource.unavailable;
    } else if (obdFresh && !gpsFresh && !imuFresh) {
      source = SensorSource.obd;
    } else if (source == SensorSource.fused && overall < .25) {
      source = obdFresh ? SensorSource.fused : SensorSource.gps;
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
