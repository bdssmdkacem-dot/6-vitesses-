import 'dart:async';

/// Transport-neutral contract for an OBD-II Bluetooth adapter.
/// A platform Bluetooth implementation can be plugged in without changing HUD logic.
abstract interface class ObdTransport {
  Stream<String> get responses;
  bool get connected;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> write(String command);
}

/// ELM327 command/session state machine. It deliberately does not own Bluetooth.
class Elm327Session {
  Elm327Session(this.transport);

  final ObdTransport transport;

  Future<void> initialize() async {
    await transport.write('ATZ\r');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await transport.write('ATE0\r');
    await transport.write('ATL0\r');
    await transport.write('ATS0\r');
    await transport.write('ATSP0\r');
  }

  Future<void> requestStandardPids() async {
    await transport.write('0104\r');
    await transport.write('0105\r');
    await transport.write('010C\r');
    await transport.write('010D\r');
    await transport.write('0111\r');
  }
}
