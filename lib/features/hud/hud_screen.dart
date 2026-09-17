import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../driving/driving_session.dart';
import '../sensors/gps_speed_service.dart';
import '../sensors/motion_sensor_service.dart';
import 'models/hud_theme.dart';
import 'widgets/speed_gauge.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});
  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  final _session = DrivingSession();
  final _gpsService = GpsSpeedService();
  final _motionService = MotionSensorService();

  StreamSubscription<GpsSample>? _gpsSub;
  StreamSubscription<MotionSample>? _motionSub;
  Timer? _gpsWatchdog;

  double _speed = 0;
  double _longitudinalAccel = 0;
  double _totalAccel = 0;
  double _maxSpeed = 0;
  double _maxAccel = 0;
  double _maxBraking = 0;
  bool _mirror = false;
  bool _ready = false;
  bool _gpsStale = true;

  HudTheme _theme = HudTheme.midnight;
  HudGaugeStyle _style = HudGaugeStyle.digital;

  @override
  void initState() {
    super.initState();
    _enterHud();
    _startSensors();
  }

  Future<void> _enterHud() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }

  Future<void> _startSensors() async {
    _gpsSub = _gpsService.samples.listen((sample) {
      if (!mounted) return;
      setState(() {
        _speed = sample.speedKmh;
        _longitudinalAccel = sample.longitudinalAcceleration;
        _gpsStale = sample.isStale;
        if (_speed > _maxSpeed) _maxSpeed = _speed;
        if (_longitudinalAccel > _maxAccel) {
          _maxAccel = _longitudinalAccel;
        }
        if (_longitudinalAccel < _maxBraking) {
          _maxBraking = _longitudinalAccel;
        }
      });

      if (_session.active && !sample.isStale) {
        _session.addSample(
          speedKmh: sample.speedKmh,
          acceleration: sample.longitudinalAcceleration,
          timestamp: sample.timestamp,
        );
      }
    });

    _motionSub = _motionService.samples.listen((sample) {
      if (!mounted) return;
      setState(() => _totalAccel = sample.totalAcceleration);
    });

    _motionService.start();
    await _gpsService.start();

    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final stale = _gpsService.isStale;
      if (stale != _gpsStale) {
        setState(() {
          _gpsStale = stale;
          if (stale) {
            _speed = 0;
            _longitudinalAccel = 0;
          }
        });
      }
    });

    if (mounted) setState(() => _ready = true);
  }

  void _settings() {
    if (_session.active) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.background,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HUD SETTINGS',
                style: TextStyle(
                  color: _theme.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: HudTheme.all.map((theme) {
                  return ChoiceChip(
                    label: Text(theme.name),
                    selected: _theme == theme,
                    onSelected: (_) {
                      setState(() => _theme = theme);
                      setSheet(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: HudGaugeStyle.values.map((style) {
                  return ChoiceChip(
                    label: Text(style.name.toUpperCase()),
                    selected: _style == style,
                    onSelected: (_) {
                      setState(() => _style = style);
                      setSheet(() {});
                    },
                  );
                }).toList(),
              ),
              SwitchListTile(
                title: const Text('Mirror HUD'),
                value: _mirror,
                onChanged: (value) => setState(() => _mirror = value),
              ),
              FilledButton.icon(
                onPressed: () {
                  _session.start();
                  Navigator.pop(context);
                  setState(() {});
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('START DRIVE'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _stopDrive() {
    _session.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      backgroundColor: _theme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SpeedGauge(
                speed: _speed,
                maxSpeed: 240,
                style: _style,
                theme: _theme,
              ),
            ),
            Positioned(
              left: 18,
              top: 14,
              child: Row(
                children: [
                  Icon(
                    _gpsStale ? Icons.gps_off : Icons.gps_fixed,
                    size: 15,
                    color: _gpsStale ? Colors.redAccent : _theme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _gpsStale ? 'GPS LOST' : 'GPS LOCK',
                    style: TextStyle(
                      color: _gpsStale ? Colors.redAccent : _theme.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!_session.active)
              Positioned(
                right: 10,
                top: 6,
                child: IconButton(
                  onPressed: _settings,
                  icon: Icon(Icons.tune, color: _theme.accent),
                  tooltip: 'Settings',
                ),
              ),
            if (_session.active)
              Positioned(
                right: 12,
                top: 10,
                child: FilledButton.icon(
                  onPressed: _stopDrive,
                  icon: const Icon(Icons.stop, size: 16),
                  label: const Text('STOP'),
                ),
              ),
            Positioned(
              left: 18,
              bottom: 14,
              child: Row(
                children: [
                  _Metric(
                    'ACCEL',
                    '\${_longitudinalAccel.toStringAsFixed(1)} m/s²',
                  ),
                  const SizedBox(width: 20),
                  _Metric(
                    'G-FORCE',
                    '\${(_totalAccel / 9.80665).toStringAsFixed(2)} G',
                  ),
                  const SizedBox(width: 20),
                  _Metric(
                    'MAX',
                    '\${_maxSpeed.toStringAsFixed(0)} km/h',
                  ),
                  if (_session.active) ...[
                    const SizedBox(width: 20),
                    _Metric(
                      'TRIP',
                      '\${_session.distanceKm.toStringAsFixed(1)} km',
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              right: 18,
              bottom: 14,
              child: _Metric(
                'BRAKE MAX',
                '\${_maxBraking.toStringAsFixed(1)} m/s²',
              ),
            ),
            if (!_ready)
              Center(
                child: Text(
                  'STARTING SENSORS...',
                  style: TextStyle(color: _theme.secondary),
                ),
              ),
          ],
        ),
      ),
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(_mirror ? -1 : 1, 1, 1),
      child: body,
    );
  }

  @override
  void dispose() {
    _gpsWatchdog?.cancel();
    _gpsSub?.cancel();
    _motionSub?.cancel();
    _gpsService.dispose();
    _motionService.dispose();
    _session.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
