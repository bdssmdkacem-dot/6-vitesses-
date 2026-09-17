import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/driving/drive_record.dart';

void main() {
  test('DriveRecord round trips through JSON', () {
    final original = DriveRecord(
      startedAt: DateTime.utc(2026, 9, 17, 20, 30),
      durationSeconds: 125,
      distanceKm: 12.34,
      averageSpeedKmh: 35.2,
      maxSpeedKmh: 91.4,
      maxAcceleration: 2.1,
      maxBraking: -3.7,
    );
    final restored = DriveRecord.fromJson(original.toJson());
    expect(restored.startedAt, original.startedAt);
    expect(restored.durationSeconds, 125);
    expect(restored.distanceKm, closeTo(12.34, 0.001));
    expect(restored.maxBraking, closeTo(-3.7, 0.001));
  });
}
