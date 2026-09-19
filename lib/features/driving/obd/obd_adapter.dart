import 'obd_telemetry.dart';

abstract interface class ObdAdapter {
  Future<void> connect();
  Future<void> connectToAddress(String address);
  Future<void> disconnect();
  Stream<ObdTelemetry> get telemetry;
  bool get connected;
}
