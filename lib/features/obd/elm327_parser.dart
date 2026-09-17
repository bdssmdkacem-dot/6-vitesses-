class Elm327Parser {
  const Elm327Parser();

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
          break;
        case 0x05:
          coolant = a - 40.0;
          break;
        case 0x0C:
          if (i + 3 < bytes.length) rpm = ((a * 256) + b) / 4;
          break;
        case 0x0D:
          speed = a.toDouble();
          break;
        case 0x11:
          throttle = a * 100 / 255;
          break;
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
        .replaceAll(RegExp(r'[\r\n>]'), ' ')
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
