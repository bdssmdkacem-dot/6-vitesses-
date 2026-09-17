import 'package:flutter/material.dart';
import 'app.dart';
import 'features/settings/app_settings.dart';
import 'features/driving/drive_history.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final history = await DriveHistory.load();
  runApp(SixVitessesApp(settings: settings, history: history));
}
