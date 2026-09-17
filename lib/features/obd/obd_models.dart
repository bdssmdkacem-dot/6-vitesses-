class ObdTelemetry {
  const ObdTelemetry({
    this.rpm,
    this.vehicleSpeedKmh,
    this.gear,
    this.throttlePercent,
    this.engineLoadPercent,
    this.coolantCelsius,
  });

  final double? rpm;
  final double? vehicleSpeedKmh;
  final int? gear;
  final double? throttlePercent;
  final double? engineLoadPercent;
  final double? coolantCelsius;
}

abstract interface class ObdAdapter {
  Future<void> connect();
  Future<void> disconnect();
  Stream<ObdTelemetry> get telemetry;
  bool get connected;
}

class NoObdAdapter implements ObdAdapter {
  @override
  bool connected = false;
  @override
  Stream<ObdTelemetry> get telemetry => const Stream.empty();
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
}
