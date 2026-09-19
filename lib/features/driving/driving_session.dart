import 'dart:async';
import 'package:flutter/foundation.dart';
import 'drive_record.dart';
import 'performance_metrics.dart';

class DrivingSession extends ChangeNotifier {
  bool _active = false;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  final PerformanceMetrics _performance = PerformanceMetrics();
  PerformanceSnapshot _snapshot =
      const PerformanceSnapshot(
        zeroToSixtySeconds: null,
        zeroToHundredSeconds: null,
        maxSpeedKmh: 0,
        maxAcceleration: 0,
        maxBraking: 0,
        maxLateralG: 0,
        distanceKm: 0,
        averageSpeedKmh: 0,
        durationSeconds: 0,
      );
  Timer? _timer;

  bool get active => _active;
  Duration get elapsed => _elapsed;
  double get distanceKm => _snapshot.distanceKm;
  double get averageSpeed => _snapshot.averageSpeedKmh;
  double get maxSpeed => _snapshot.maxSpeedKmh;
  double get maxAcceleration => _snapshot.maxAcceleration;
  double get maxBraking => _snapshot.maxBraking;
  PerformanceSnapshot get performance => _snapshot;

  void start() {
    _timer?.cancel();
    _active = true;
    _startedAt = DateTime.now();
    _elapsed = Duration.zero;
    _performance.reset(_startedAt!);
    _snapshot = _performance.snapshot(_startedAt!);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null) {
        _elapsed = DateTime.now().difference(_startedAt!);
        _snapshot = _performance.snapshot(DateTime.now());
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void addSample({
    required double speedKmh,
    required double acceleration,
    double lateralAcceleration = 0,
    DateTime? timestamp,
  }) {
    if (!_active) return;
    final now = timestamp ?? DateTime.now();
    _performance.addSample(
      speedKmh: speedKmh,
      longitudinalAcceleration: acceleration,
      lateralAcceleration: lateralAcceleration,
      timestamp: now,
    );
    _snapshot = _performance.snapshot(now);
    _elapsed = now.difference(_startedAt!).isNegative
        ? Duration.zero
        : now.difference(_startedAt!);
    notifyListeners();
  }

  DriveRecord stop() {
    final started = _startedAt ?? DateTime.now();
    final now = DateTime.now();
    _snapshot = _performance.snapshot(now);
    _elapsed = now.difference(started);
    _active = false;
    _timer?.cancel();
    _timer = null;

    final record = DriveRecord(
      startedAt: started,
      durationSeconds: _snapshot.durationSeconds,
      distanceKm: _snapshot.distanceKm,
      averageSpeedKmh: _snapshot.averageSpeedKmh,
      maxSpeedKmh: _snapshot.maxSpeedKmh,
      maxAcceleration: _snapshot.maxAcceleration,
      maxBraking: _snapshot.maxBraking,
      zeroToSixtySeconds: _snapshot.zeroToSixtySeconds,
      zeroToHundredSeconds: _snapshot.zeroToHundredSeconds,
      maxLateralG: _snapshot.maxLateralG,
    );
    notifyListeners();
    return record;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
