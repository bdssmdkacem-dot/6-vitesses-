import 'obd_models.dart';

class ObdService {
  ObdService({ObdAdapter? adapter}) : adapter = adapter ?? NoObdAdapter();

  final ObdAdapter adapter;

  bool get connected => adapter.connected;
  Stream<ObdTelemetry> get telemetry => adapter.telemetry;

  Future<bool> connect() async {
    try {
      await adapter.connect();
      return adapter.connected;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() => adapter.disconnect();
}
