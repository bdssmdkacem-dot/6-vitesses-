import 'package:flutter_test/flutter_test.dart';
import 'package:six_vitesses/app.dart';
import 'package:six_vitesses/features/driving/drive_history.dart';
import 'package:six_vitesses/features/settings/app_settings.dart';

void main() {
  testWidgets('6 Vitesses app starts', (tester) async {
    final settings = AppSettings();
    final history = await DriveHistory.load();
    await tester.pumpWidget(SixVitessesApp(settings: settings, history: history));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('STARTING SENSORS...'), findsOneWidget);
  });
}
