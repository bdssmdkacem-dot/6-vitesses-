import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/features/driving/driving_session.dart';

void main() {
  test('distance uses real sample interval', () {
    final session = DrivingSession();
    final t0 = DateTime(2026, 1, 1, 12);
    session.start();
    session.addSample(speedKmh: 72, acceleration: 2, timestamp: t0);
    session.addSample(
      speedKmh: 72,
      acceleration: 0,
      timestamp: t0.add(const Duration(seconds: 5)),
    );

    expect(session.distanceKm, closeTo(0.1, 0.000001));

    // During acceleration, trapezoidal integration uses the mean of the
    // consecutive samples instead of charging the full current speed.
    session.addSample(
      speedKmh: 36,
      acceleration: 2,
      timestamp: t0.add(const Duration(seconds: 6)),
    );
    expect(session.distanceKm, closeTo(0.115, 0.000001));
    expect(session.maxAcceleration, 2);
    expect(session.maxBraking, 0);
    session.dispose();
  });
}
