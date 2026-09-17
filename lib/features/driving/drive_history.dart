import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'drive_record.dart';

class DriveHistory extends ChangeNotifier {
  DriveHistory._(this._prefs, this._records);
  final SharedPreferences _prefs;
  final List<DriveRecord> _records;
  static const _key = 'drive_history';

  static Future<DriveHistory> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? <String>[];
    final records = <DriveRecord>[];
    for (final item in raw) {
      try { records.add(DriveRecord.fromJson(jsonDecode(item) as Map<String, dynamic>)); } catch (_) {}
    }
    return DriveHistory._(prefs, records);
  }

  List<DriveRecord> get records => List.unmodifiable(_records);

  Future<void> add(DriveRecord record) async {
    _records.insert(0, record);
    if (_records.length > 50) _records.removeRange(50, _records.length);
    await _prefs.setStringList(_key, _records.map((e) => jsonEncode(e.toJson())).toList());
    notifyListeners();
  }

  Future<void> clear() async {
    _records.clear();
    await _prefs.remove(_key);
    notifyListeners();
  }
}
