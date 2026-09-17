import 'package:flutter/material.dart';
import 'app.dart';
import 'features/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(SixVitessesApp(settings: settings));
}
