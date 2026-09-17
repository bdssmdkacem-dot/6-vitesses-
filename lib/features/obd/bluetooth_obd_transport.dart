import 'dart:async';

import 'obd_connection.dart';

/// Production boundary for Android Bluetooth Classic.
///
/// The actual RFCOMM implementation is intentionally isolated here so the
/// ELM327 protocol layer never depends on Android APIs.
class BluetoothObdTransport implements ObdTransport {
  BluetoothObdTransport({required this.deviceId});

  final String deviceId;
  final StreamController<String> _responses = StreamController<String>.broadcast();
  bool _connected = false;

  @override
  Stream<String> get responses => _responses.stream;

  @override
  bool get connected => _connected;

  @override
  Future<void> connect() async {
    // Android Bluetooth Classic implementation is injected in the platform
    // layer. Do not fake a connection when no transport is available.
    throw UnsupportedError('Bluetooth RFCOMM transport is not configured');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _responses.close();
  }

  @override
  Future<void> write(String command) async {
    if (!_connected) {
      throw StateError('OBD transport is not connected');
    }
  }
}
