import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/obd/elm327_parser.dart';

void main() {
  const parser = Elm327Parser();

  test('parses standard ELM327 PIDs', () {
    final result = parser.parse('41 0C 1A F8\r41 0D 3C\r41 05 5A\r41 11 80\r41 04 80');
    expect(result.rpm, closeTo(1726, 0.01));
    expect(result.vehicleSpeedKmh, 60);
    expect(result.coolantCelsius, 50);
    expect(result.throttlePercent, closeTo(50.196, 0.01));
    expect(result.engineLoadPercent, closeTo(50.196, 0.01));
  });

  test('ignores non-hex noise', () {
    final result = parser.parse('SEARCHING...\r41 0D 28\r>');
    expect(result.vehicleSpeedKmh, 40);
  });
}
