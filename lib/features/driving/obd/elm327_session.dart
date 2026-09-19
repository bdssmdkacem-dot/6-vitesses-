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
    return _parsePidValue(pid, response);
  }

  double? _parsePidValue(String pid, String response) {
    final bytes = RegExp(r'[0-9A-Fa-f]{2}')
        .allMatches(response)
        .map((m) => int.parse(m.group(0)!, radix: 16))
        .toList();
    if (bytes.length < 3) return null;
    final requested = int.tryParse(pid.replaceFirst('01', ''), radix: 16);
    if (requested == null) return null;
    final index = bytes.indexWhere((value) => value == 0x41);
    if (index < 0 || index + 1 >= bytes.length || bytes[index + 1] != requested) return null;
    final data = bytes.sublist(index + 2);
    if (data.isEmpty) return null;
    switch (requested) {
      case 0x04:
      case 0x05:
      case 0x0D:
      case 0x11:
        return data.first.toDouble();
      case 0x0C:
        if (data.length < 2) return null;
        return ((data[0] * 256) + data[1]).toDouble();
      default:
        return null;
    }
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
