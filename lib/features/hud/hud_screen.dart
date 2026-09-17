import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});
  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  double _speedKmh = 0, _accel = 0, _maxSpeed = 0, _maxAccel = 0;
  bool _mirror = false, _running = false;
  String _gpsStatus = 'GPS';

  @override
  void initState() {
    super.initState();
    _enterHudMode();
    _startSensors();
  }

  Future<void> _enterHudMode() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }

  Future<void> _startSensors() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _gpsStatus = 'GPS OFF');
    } else {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsStatus = 'GPS PERMISSION');
      } else {
        _positionSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
          ),
        ).listen((position) {
          final speed = (position.speed * 3.6).clamp(0, 400).toDouble();
          if (!mounted) return;
          setState(() {
            _speedKmh = speed;
            if (speed > _maxSpeed) _maxSpeed = speed;
            _gpsStatus = position.accuracy <= 25
                ? 'GPS'
                : 'GPS ±${position.accuracy.round()}m';
          });
        });
      }
    }

    _accelSub = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      final magnitude = _sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (!mounted) return;
      setState(() {
        _accel = magnitude;
        if (magnitude > _maxAccel) _maxAccel = magnitude;
      });
    });
    if (mounted) setState(() => _running = true);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _accelSub?.cancel();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      onTap: () => setState(() => _mirror = !_mirror),
      child: Container(
        color: const Color(0xFF050505),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_gpsStatus, style: const TextStyle(fontSize: 14)),
                    Text(
                      _speedKmh.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 150,
                        fontWeight: FontWeight.w800,
                        height: .85,
                      ),
                    ),
                    const Text('km/h', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Metric(label: 'ACCEL', value: '${_accel.toStringAsFixed(1)} m/s²'),
                        const SizedBox(width: 36),
                        _Metric(label: 'MAX', value: '${_maxSpeed.toStringAsFixed(0)} km/h'),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                top: 12,
                child: Text(
                  _running ? '6 VITESSES • TAP = MIRROR' : 'WAITING',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(_mirror ? -1 : 1, 1, 1),
      child: content,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
    ],
  );
}

double _sqrt(double value) {
  if (value <= 0) return 0;
  var guess = value / 2;
  for (var i = 0; i < 16; i++) {
    guess = (guess + value / guess) / 2;
  }
  return guess;
}
