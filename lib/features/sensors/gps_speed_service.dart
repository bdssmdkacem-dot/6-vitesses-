import 'dart:async';
import 'dart:collection';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class GpsSample {
  const GpsSample({
    required this.speedKmh,
    required this.accuracyM,
    required this.longitudinalAcceleration,
    required this.timestamp,
    required this.isStale,
    this.position,
    this.headingDegrees = 0,
    this.speedConfidence = 0,
    this.jumpRejected = false,
  });

  final double speedKmh, accuracyM, longitudinalAcceleration;
  final LatLng? position;
  final double headingDegrees;
  final DateTime timestamp;
  final bool isStale;
  final double speedConfidence;
  final bool jumpRejected;
}

class GpsSpeedService {
  GpsSpeedService({
    this.windowSize = 5,
    this.maxAccuracyMeters = 100,
    this.staleAfter = const Duration(seconds: 4),
    this.maxJumpSpeedKmh = 320,
  });

  final int windowSize;
  final double maxAccuracyMeters;
  final Duration staleAfter;
  final double maxJumpSpeedKmh;

  final ListQueue<double> _window = ListQueue<double>();
  Position? _previous;
  DateTime? _lastUpdate;
  StreamSubscription<Position>? _subscription;
  StreamSubscription<ServiceStatus>? _serviceSubscription;
  Timer? _retryTimer;
  final _controller = StreamController<GpsSample>.broadcast();
  bool _starting = false, _disposed = false;
  LocationPermission _permission = LocationPermission.denied;
  String _status = 'STARTING';
  String? _lastError;
  int _jumpRejections = 0;

  Stream<GpsSample> get samples => _controller.stream;
  bool get isStale =>
      _lastUpdate == null ||
      DateTime.now().difference(_lastUpdate!) > staleAfter;
  String get status => _status;
  String? get lastError => _lastError;
  LocationPermission get permission => _permission;
  int get jumpRejections => _jumpRejections;

  Future<LocationPermission> refreshPermission() async {
    _permission = await Geolocator.checkPermission();
    return _permission;
  }

  Future<LocationPermission> requestLocationPermission() async {
    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }
    return _permission;
  }

  Future<void> start() async {
    if (_disposed || _starting) return;
    _starting = true;
    try {
      await _ensurePermissionAndStream();
    } finally {
      _starting = false;
      if (!_disposed) _scheduleRetry();
    }
  }

  Future<void> _ensurePermissionAndStream() async {
    if (_disposed) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      _status = 'LOCATION OFF';
      _emitStale();
      _listenForServiceChanges();
      return;
    }
    final permission = await requestLocationPermission();
    if (permission == LocationPermission.denied) {
      _status = 'PERMISSION DENIED';
      _emitStale();
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      _status = 'PERMISSION BLOCKED';
      _emitStale();
      return;
    }

    _listenForServiceChanges();
    await _subscription?.cancel();
    _subscription = null;
    _status = 'WAITING FOR FIX';
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosition,
      onError: (Object error) {
        _lastError = error.toString();
        _status = 'STREAM ERROR';
        _scheduleRetry(immediate: true);
      },
      cancelOnError: false,
    );
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 12));
      _onPosition(position);
    } on TimeoutException {
      _status = 'NO FIX YET';
    } catch (error) {
      _lastError = error.toString();
      _status = 'FIX ERROR';
    }
  }

  void _listenForServiceChanges() {
    _serviceSubscription ??= Geolocator.getServiceStatusStream().listen((status) {
      if (_disposed) return;
      if (status == ServiceStatus.enabled) {
        _scheduleRetry(immediate: true);
      } else {
        _status = 'LOCATION OFF';
        _emitStale();
      }
    });
  }

  void _scheduleRetry({bool immediate = false}) {
    _retryTimer?.cancel();
    if (_disposed) return;
    _retryTimer = Timer(
      immediate ? const Duration(seconds: 2) : const Duration(seconds: 8),
      () {
        if (!_disposed && (_subscription == null || isStale)) start();
      },
    );
  }

  bool isPlausibleJump({
    required LatLng previous,
    required LatLng current,
    required Duration elapsed,
    required double previousAccuracy,
    required double currentAccuracy,
  }) {
    final seconds = elapsed.inMilliseconds / 1000.0;
    if (seconds <= 0 || seconds > 10) return true;
    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    final impliedSpeedKmh = distance / seconds * 3.6;
    return !(impliedSpeedKmh > maxJumpSpeedKmh &&
        distance > mathMax(40, previousAccuracy + currentAccuracy));
  }

  void _onPosition(Position position) {
    if (_disposed) return;
    if (position.timestamp.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return;
    }
    if (position.accuracy.isNaN ||
        position.accuracy > maxAccuracyMeters ||
        position.speed.isNaN ||
        position.speed < 0) {
      return;
    }

    final previous = _previous;
    if (previous != null) {
      final dt = position.timestamp.difference(previous.timestamp).inMilliseconds /
          1000.0;
      if (dt > 0 && dt <= 10) {
        final plausible = isPlausibleJump(
          previous: LatLng(previous.latitude, previous.longitude),
          current: LatLng(position.latitude, position.longitude),
          elapsed: Duration(milliseconds: (dt * 1000).round()),
          previousAccuracy: previous.accuracy,
          currentAccuracy: position.accuracy,
        );
        if (!plausible) {
          _jumpRejections++;
          _status = 'GPS JUMP REJECTED';
          return;
        }
      }
    }

    final now = position.timestamp;
    final rawSpeed = (position.speed * 3.6).clamp(0.0, 400.0).toDouble();
    _window.addLast(rawSpeed);
    while (_window.length > windowSize) {
      _window.removeFirst();
    }
    final speed = _median(_window);
    var acceleration = 0.0;
    if (previous != null) {
      final dt = now.difference(previous.timestamp).inMilliseconds / 1000.0;
      if (dt >= 0.2 && dt <= 10) {
        acceleration = ((rawSpeed - previous.speed * 3.6) / dt / 3.6)
            .clamp(-12.0, 12.0)
            .toDouble();
      }
    }

    _previous = position;
    _lastUpdate = now;
    _status = 'LOCKED';
    _lastError = null;
    _retryTimer?.cancel();

    final speedConfidence =
        (1.0 - (position.accuracy / maxAccuracyMeters)).clamp(0.0, 1.0);
    _controller.add(
      GpsSample(
        speedKmh: speed,
        accuracyM: position.accuracy,
        longitudinalAcceleration: acceleration,
        timestamp: now,
        isStale: false,
        position: LatLng(position.latitude, position.longitude),
        headingDegrees: position.heading,
        speedConfidence: speedConfidence,
      ),
    );
  }

  void _emitStale() {
    if (_disposed || _controller.isClosed) return;
    _controller.add(
      GpsSample(
        speedKmh: _window.isEmpty ? 0 : _median(_window),
        accuracyM: double.infinity,
        longitudinalAcceleration: 0,
        timestamp: DateTime.now(),
        isStale: true,
        position: null,
        headingDegrees: 0,
        speedConfidence: 0,
      ),
    );
  }

  double _median(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _serviceSubscription?.cancel();
    _subscription?.cancel();
    _controller.close();
  }
}

double mathMax(double a, double b) => a > b ? a : b;
