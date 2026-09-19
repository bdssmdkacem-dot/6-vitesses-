import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/driving/obd/elm327_session.dart';
import 'package:six_vitesses/features/driving/obd/obd_transport.dart';
import 'package:six_vitesses/features/driving/obd/obd_telemetry.dart';

class FakeObdTransport implements ObdTransport {
  final Map<String, String> responses;
  FakeObdTransport(this.responses);
  bool _connected = false;
  @override bool get connected => _connected;
  @override Future<void> connect() async => _connected = true;
  @override Future<void> connectToAddress(String address) async => _connected = true;
  @override Future<void> disconnect() async => _connected = false;
  @override Future<String> send(String command) async => responses[command] ?? '';
}

void main() {
  test('decodes standard ELM327 telemetry', () async {
    final transport = FakeObdTransport({
      '0104': '41 04 80',
      '0105': '41 05 6E',
      '010C': '41 0C 1A F8',
      '010D': '41 0D 50',
      '0111': '41 11 40',
    });
    final obd = Elm327Session(transport);
    await obd.connect();
    final telemetry = await obd.readStandardTelemetry();
    expect(telemetry.source, ObdTelemetrySource.obd);
    expect(telemetry.engineLoad, closeTo(50.196, .01));
    expect(telemetry.coolantTemperatureC, 70);
    expect(telemetry.rpm, 1726);
    expect(telemetry.vehicleSpeedKmh, 80);
    expect(telemetry.throttlePosition, closeTo(25.098, .01));
    obd.dispose();
  });
}
