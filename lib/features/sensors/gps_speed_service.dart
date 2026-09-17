import 'dart:async';
import 'dart:collection';

import 'package:geolocator/geolocator.dart';

class GpsSample {
  const GpsSample({
    required this.speedKmh,
    required this.accuracyM,
    required this.longitudinalAcceleration,
    required this.timestamp,
    required this.isStale,
  });

  final double speedKmh;
  final double accuracyM;
  final double longitudinalAcceleration;
  final DateTime timestamp;
  final bool isStale;
}

class GpsSpeedService {
  GpsSpeedService({
    this.windowSize = 5,
    this.maxAccuracyMeters = 35,
    this.staleAfter = const Duration(seconds: 4),
  });

  final int windowSize;
  final double maxAccuracyMeters;
  final Duration staleAfter;

  final ListQueue<double> _speedWindow = ListQueue<double>();
  Position? _previous;
  DateTime? _lastUpdate;
  double _filteredAcceleration = 0;

  StreamSubscription<Position>? _subscription;
  final _controller = StreamController<GpsSample>.broadcast();

  Stream<GpsSample> get samples => _controller.stream;

  Future<void> start() async {
    await stop();

    if (!await Geolocator.isLocationServiceEnabled()) {
      _emitStale();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _emitStale();
      return;
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen(
      _onPosition,
      onError: (_) => _emitStale(),
    );

    _emitStale();
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onPosition(Position position) {
    if (position.accuracy.isNaN ||
        position.accuracy > maxAccuracyMeters ||
        position.speed.isNaN ||
        position.speed < 0) {
      return;
    }

    final now = position.timestamp;
    final rawSpeed = (position.speed * 3.6).clamp(0.0, 400.0).toDouble();

    _speedWindow.addLast(rawSpeed);
    while (_speedWindow.length > windowSize) {
      _speedWindow.removeFirst();
    }

    final speed = _median(_speedWindow);
    var acceleration = 0.0;
    final previous = _previous;

    if (previous != null) {
      final dt = now.difference(previous.timestamp).inMilliseconds / 1000.0;
      if (dt >= 0.2 && dt <= 3.0) {
        final previousSpeed = previous.speed * 3.6;
        final rawAcceleration = (speed - previousSpeed) / 3.6 / dt;
        acceleration = _filteredAcceleration * 0.65 + rawAcceleration * 0.35;
        acceleration = acceleration.clamp(-12.0, 12.0).toDouble();
      }
    }

    // Avoid displaying tiny GPS noise as movement/acceleration while stopped.
    if (speed < 1.5) {
      acceleration *= 0.35;
      if (acceleration.abs() < 0.15) {
        acceleration = 0;
      }
    }

    _filteredAcceleration = acceleration;
    _previous = Position(
      longitude: position.longitude,
      latitude: position.latitude,
      timestamp: position.timestamp,
      accuracy: position.accuracy,
      altitude: position.altitude,
      altitudeAccuracy: position.altitudeAccuracy,
      heading: position.heading,
      headingAccuracy: position.headingAccuracy,
      speed: speed / 3.6,
      speedAccuracy: position.speedAccuracy,
      floor: position.floor,
      isMocked: position.isMocked,
    );
    _lastUpdate = now;
    _lastAccuracy = position.accuracy;

    _controller.add(
      GpsSample(
        speedKmh: speed,
        accuracyM: position.accuracy,
        longitudinalAcceleration: acceleration,
        timestamp: now,
        isStale: false,
      ),
    );
  }

  void _emitStale() {
    _controller.add(
      GpsSample(
        speedKmh: 0,
        accuracyM: double.infinity,
        longitudinalAcceleration: 0,
        timestamp: DateTime.now(),
        isStale: true,
      ),
    );
  }

  bool get isStale {
    final last = _lastUpdate;
    return last == null || DateTime.now().difference(last) > staleAfter;
  }

  double get accuracyMeters {
    final last = _lastUpdate;
    if (last == null) return double.infinity;
    return _lastAccuracy;
  }

  double _lastAccuracy = double.infinity;

  double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
