import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:six_vitesses/app.dart';
import 'package:six_vitesses/features/driving/drive_history.dart';
import 'package:six_vitesses/features/settings/app_settings.dart';

void main() {
  testWidgets('6 Vitesses app starts', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    final history = await DriveHistory.load();

    await tester.pumpWidget(
      SixVitessesApp(settings: settings, history: history),
    );

    // HudScreen waits for the native Android permission request to settle
    // before checking the resulting permission state.
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.byType(SixVitessesApp), findsOneWidget);
  });
}
