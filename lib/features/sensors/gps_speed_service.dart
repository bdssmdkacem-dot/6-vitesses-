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
    this.maxAccuracyMeters = 50,
    this.staleAfter = const Duration(seconds: 4),
  });

  final int windowSize;
  final double maxAccuracyMeters;
  final Duration staleAfter;
  final ListQueue<double> _window = ListQueue<double>();
  Position? _previous;
  DateTime? _lastUpdate;

  StreamSubscription<Position>? _subscription;
  final _controller = StreamController<GpsSample>.broadcast();

  Stream<GpsSample> get samples => _controller.stream;

  Future<void> start() async {
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
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen(_onPosition);

    _emitStale();
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
    _window.addLast(rawSpeed);
    while (_window.length > windowSize) {
      _window.removeFirst();
    }

    final speed = _median(_window);
    var acceleration = 0.0;
    final previous = _previous;
    if (previous != null) {
      final dt = now.difference(previous.timestamp).inMilliseconds / 1000.0;
      if (dt >= 0.2 && dt <= 10) {
        final previousSpeed = previous.speed * 3.6;
        acceleration = (rawSpeed - previousSpeed) / dt / 3.6;
        acceleration = acceleration.clamp(-12.0, 12.0).toDouble();
      }
    }

    _previous = position;
    _lastUpdate = now;
    _controller.add(GpsSample(
      speedKmh: speed,
      accuracyM: position.accuracy,
      longitudinalAcceleration: acceleration,
      timestamp: now,
      isStale: false,
    ));
  }

  void _emitStale() {
    _controller.add(GpsSample(
      speedKmh: 0,
      accuracyM: double.infinity,
      longitudinalAcceleration: 0,
      timestamp: DateTime.now(),
      isStale: true,
    ));
  }

  bool get isStale {
    final last = _lastUpdate;
    return last == null || DateTime.now().difference(last) > staleAfter;
  }

  double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
  }
}
