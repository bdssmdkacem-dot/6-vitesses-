import 'dart:async';

import 'obd_models.dart';
import 'obd_service.dart';

enum ObdConnectionState { disabled, disconnected, connecting, connected, error }

class ObdController {
  ObdController({ObdService? service}) : _service = service ?? ObdService();

  final ObdService _service;
  final _stateController = StreamController<ObdConnectionState>.broadcast();
  StreamSubscription<ObdTelemetry>? _telemetrySubscription;
  Timer? _pollTimer;

  ObdConnectionState _state = ObdConnectionState.disconnected;
  ObdConnectionState get state => _state;
  Stream<ObdConnectionState> get states => _stateController.stream;
  Stream<ObdTelemetry> get telemetry => _service.telemetry;

  Future<bool> connect() async {
    _setState(ObdConnectionState.connecting);
    try {
      final ok = await _service.connect();
      if (!ok) {
        _setState(ObdConnectionState.error);
        return false;
      }
      _setState(ObdConnectionState.connected);
      return true;
    } catch (_) {
      _setState(ObdConnectionState.error);
      return false;
    }
  }

  Future<void> startPolling() async {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {});
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
    await _service.disconnect();
    _setState(ObdConnectionState.disconnected);
  }

  void _setState(ObdConnectionState value) {
    _state = value;
    if (!_stateController.isClosed) _stateController.add(value);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
  }
}
