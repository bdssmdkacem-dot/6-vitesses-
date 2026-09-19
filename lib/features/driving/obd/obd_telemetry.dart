enum ObdTelemetrySource { unavailable, gps, obd }

class ObdTelemetry {
  const ObdTelemetry({
    required this.source,
    this.engineLoad,
    this.coolantTemperatureC,
    this.rpm,
    this.vehicleSpeedKmh,
    this.throttlePosition,
    this.timestamp,
  });

  final ObdTelemetrySource source;
  final double? engineLoad;
  final double? coolantTemperatureC;
  final double? rpm;
  final double? vehicleSpeedKmh;
  final double? throttlePosition;
  final DateTime? timestamp;

  bool get available => source == ObdTelemetrySource.obd;
}
