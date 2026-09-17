class Elm327Parser {
  const Elm327Parser();

  /// Parses one or more ELM327 response lines and extracts standard OBD-II PIDs.
  /// Supported: 04 engine load, 05 coolant, 0C RPM, 0D speed, 11 throttle.
  ObdPidValues parse(String response) {
    double? rpm;
    double? speed;
    double? coolant;
    double? load;
    double? throttle;

    final bytes = _hexBytes(response);
    for (var i = 0; i + 2 < bytes.length; i++) {
      if (bytes[i] != 0x41) continue;
      final pid = bytes[i + 1];
      final a = bytes[i + 2];
      final b = i + 3 < bytes.length ? bytes[i + 3] : 0;
      switch (pid) {
        case 0x04:
          load = a * 100 / 255;
        case 0x05:
          coolant = a - 40.0;
        case 0x0C:
          if (i + 3 < bytes.length) rpm = ((a * 256) + b) / 4;
        case 0x0D:
          speed = a.toDouble();
        case 0x11:
          throttle = a * 100 / 255;
      }
    }
    return ObdPidValues(
      rpm: rpm,
      vehicleSpeedKmh: speed,
      coolantCelsius: coolant,
      engineLoadPercent: load,
      throttlePercent: throttle,
    );
  }

  List<int> _hexBytes(String response) {
    final cleaned = response
        .replaceAll(RegExp(r'[
>]'), ' ')
        .replaceAll(RegExp(r'[^0-9A-Fa-f ]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((s) => s.length == 2)
        .map((s) => int.tryParse(s, radix: 16))
        .whereType<int>()
        .toList();
  }
}

class ObdPidValues {
  const ObdPidValues({
    this.rpm,
    this.vehicleSpeedKmh,
    this.coolantCelsius,
    this.engineLoadPercent,
    this.throttlePercent,
  });

  final double? rpm;
  final double? vehicleSpeedKmh;
  final double? coolantCelsius;
  final double? engineLoadPercent;
  final double? throttlePercent;
}
