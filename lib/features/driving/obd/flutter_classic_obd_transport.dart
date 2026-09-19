import 'dart:async';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'obd_transport.dart';

class FlutterClassicObdTransport implements ObdTransport {
  FlutterClassicObdTransport({FlutterClassicBluetooth? bluetooth})
      : _bluetooth = bluetooth ?? FlutterClassicBluetooth();

  final FlutterClassicBluetooth _bluetooth;
  dynamic _connection;
  bool _connected = false;

  @override
  bool get connected => _connected;

  @override
  Future<void> connectToAddress(String address) async {
    _connection = await _bluetooth.connect(
      address: address,
      timeout: const Duration(seconds: 15),
    );
    _connected = true;
  }

  @override
  Future<void> connect() async {
    throw StateError('Use connectToAddress(address) for an OBD-II adapter.');
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    _connected = false;
    if (connection != null) {
      try {
        await connection.finish();
      } finally {
        connection.dispose();
      }
    }
  }

  @override
  Future<String> send(String command) async {
    final connection = _connection;
    if (!_connected || connection == null) {
      throw StateError('OBD-II adapter is not connected.');
    }
    final response = await connection.sendAndReceive(
      command,
      timeout: const Duration(seconds: 2),
      where: (line) => line.trim().isNotEmpty && line.trim() != command,
    );
    return response;
  }
}
