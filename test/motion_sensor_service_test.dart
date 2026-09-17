import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/sensors/motion_sensor_service.dart';

void main() {
  test('motion service accepts a custom sampling period', () {
    final service = MotionSensorService(
      samplingPeriod: const Duration(milliseconds: 200),
    );
    expect(service.samplingPeriod.inMilliseconds, 200);
    service.dispose();
  });
}
