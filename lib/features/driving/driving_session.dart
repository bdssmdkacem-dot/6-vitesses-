import 'dart:async';
import 'package:flutter/foundation.dart';

class DrivingSession extends ChangeNotifier {
  bool _active = false;
  DateTime? _startedAt;
  DateTime? _lastSampleAt;
  Duration _elapsed = Duration.zero;
  double _distanceKm = 0;
  double _speedSum = 0;
  double _maxSpeed = 0;
  double _maxAcceleration = 0;
  double _maxBraking = 0;
  int _samples = 0;
  Timer? _timer;

  bool get active => _active;
  Duration get elapsed => _elapsed;
  double get distanceKm => _distanceKm;
  double get averageSpeed => _samples == 0 ? 0 : _speedSum / _samples;
  double get maxSpeed => _maxSpeed;
  double get maxAcceleration => _maxAcceleration;
  double get maxBraking => _maxBraking;

  void start() {
    _timer?.cancel();
    _active = true;
    _startedAt = DateTime.now();
    _lastSampleAt = null;
    _elapsed = Duration.zero;
    _distanceKm = 0;
    _speedSum = 0;
    _samples = 0;
    _maxSpeed = 0;
    _maxAcceleration = 0;
    _maxBraking = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null) {
        _elapsed = DateTime.now().difference(_startedAt!);
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void addSample({
    required double speedKmh,
    required double acceleration,
    DateTime? timestamp,
  }) {
    if (!_active) return;
    final now = timestamp ?? DateTime.now();
    final previous = _lastSampleAt;
    if (previous != null) {
      final dt = now.difference(previous).inMilliseconds / 1000.0;
      if (dt > 0 && dt <= 10) {
        _distanceKm += speedKmh * dt / 3600.0;
      }
    }
    _lastSampleAt = now;
    _samples++;
    _speedSum += speedKmh;
    if (speedKmh > _maxSpeed) _maxSpeed = speedKmh;
    if (acceleration > _maxAcceleration) _maxAcceleration = acceleration;
    if (acceleration < _maxBraking) _maxBraking = acceleration;
    notifyListeners();
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
