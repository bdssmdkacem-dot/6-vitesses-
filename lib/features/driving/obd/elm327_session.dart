import 'dart:async';
import 'obd_adapter.dart';
import 'obd_transport.dart';
import 'obd_telemetry.dart';

class Elm327Session implements ObdAdapter {
  Elm327Session(this.transport);

  final ObdTransport transport;
  final _controller = StreamController<ObdTelemetry>.broadcast();
  bool _connected = false;

  @override
  bool get connected => _connected;

  @override
  Stream<ObdTelemetry> get telemetry => _controller.stream;

  @override
  Future<void> connect() async {
    await transport.connect();
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await transport.disconnect();
  }

  Future<double?> readPid(String pid) async {
    if (!_connected) return null;
    final response = await transport.send(pid);
    return _parseFirstValue(response);
  }

  double? _parseFirstValue(String response) {
    final match = RegExp(r'([0-9A-Fa-f]{2})').firstMatch(response);
    if (match == null) return null;
    return int.parse(match.group(1)!, radix: 16).toDouble();
  }

  Future<ObdTelemetry> readStandardTelemetry() async {
    if (!_connected) return const ObdTelemetry(source: ObdTelemetrySource.unavailable);
    final load = await readPid('0104');
    final coolant = await readPid('0105');
    final rpmRaw = await readPid('010C');
    final speed = await readPid('010D');
    final throttle = await readPid('0111');
    return ObdTelemetry(
      source: ObdTelemetrySource.obd,
      engineLoad: load == null ? null : load * 100 / 255,
      coolantTemperatureC: coolant == null ? null : coolant - 40,
      rpm: rpmRaw == null ? null : rpmRaw * 4,
      vehicleSpeedKmh: speed,
      throttlePosition: throttle == null ? null : throttle * 100 / 255,
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}
