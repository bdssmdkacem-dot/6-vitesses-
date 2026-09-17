import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../hud/models/hud_theme.dart';

enum SpeedUnit { kmh, mph }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;
  static const _themeKey = 'hud_theme';
  static const _gaugeKey = 'hud_gauge';
  static const _mirrorKey = 'hud_mirror';
  static const _gearKey = 'hud_gear';
  static const _unitKey = 'speed_unit';
  static const _limitKey = 'speed_limit';
  static const _vehicleNameKey = 'vehicle_name';
  static const _vehicleModelKey = 'vehicle_model';
  static const _obdEnabledKey = 'obd_enabled';

  HudTheme _theme = HudTheme.midnight;
  HudGaugeStyle _gauge = HudGaugeStyle.digital;
  bool _mirror = false;
  int _gear = 0;
  SpeedUnit _unit = SpeedUnit.kmh;
  double _speedLimit = 240;
  String _vehicleName = 'My Car';
  String _vehicleModel = '';
  bool _obdEnabled = false;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings._(prefs);
    s._theme = _themeFromIndex(prefs.getInt(_themeKey) ?? 0);
    final gaugeIndex = (prefs.getInt(_gaugeKey) ?? 0).clamp(0, HudGaugeStyle.values.length - 1).toInt();
    s._gauge = HudGaugeStyle.values[gaugeIndex];
    s._mirror = prefs.getBool(_mirrorKey) ?? false;
    s._gear = (prefs.getInt(_gearKey) ?? 0).clamp(0, 6).toInt();
    final unitIndex = (prefs.getInt(_unitKey) ?? 0).clamp(0, SpeedUnit.values.length - 1).toInt();
    s._unit = SpeedUnit.values[unitIndex];
    s._speedLimit = prefs.getDouble(_limitKey) ?? 240;
    s._vehicleName = prefs.getString(_vehicleNameKey) ?? 'My Car';
    s._vehicleModel = prefs.getString(_vehicleModelKey) ?? '';
    s._obdEnabled = prefs.getBool(_obdEnabledKey) ?? false;
    return s;
  }

  static HudTheme _themeFromIndex(int i) => HudTheme.all[i.clamp(0, HudTheme.all.length - 1).toInt()];

  HudTheme get theme => _theme;
  HudGaugeStyle get gauge => _gauge;
  bool get mirror => _mirror;
  int get gear => _gear;
  SpeedUnit get unit => _unit;
  double get speedLimit => _speedLimit;
  String get vehicleName => _vehicleName;
  String get vehicleModel => _vehicleModel;
  bool get obdEnabled => _obdEnabled;

  double toDisplaySpeed(double kmh) => _unit == SpeedUnit.kmh ? kmh : kmh * 0.621371;

  Future<void> setTheme(HudTheme value) async { _theme = value; await _prefs.setInt(_themeKey, HudTheme.all.indexOf(value)); notifyListeners(); }
  Future<void> setGauge(HudGaugeStyle value) async { _gauge = value; await _prefs.setInt(_gaugeKey, value.index); notifyListeners(); }
  Future<void> setMirror(bool value) async { _mirror = value; await _prefs.setBool(_mirrorKey, value); notifyListeners(); }
  Future<void> setGear(int value) async { _gear = value.clamp(0, 6).toInt(); await _prefs.setInt(_gearKey, _gear); notifyListeners(); }
  Future<void> setUnit(SpeedUnit value) async { _unit = value; await _prefs.setInt(_unitKey, value.index); notifyListeners(); }
  Future<void> setSpeedLimit(double value) async { _speedLimit = value.clamp(60, 360).toDouble(); await _prefs.setDouble(_limitKey, _speedLimit); notifyListeners(); }
  Future<void> setVehicle({required String name, required String model}) async {
    _vehicleName = name.trim().isEmpty ? 'My Car' : name.trim();
    _vehicleModel = model.trim();
    await _prefs.setString(_vehicleNameKey, _vehicleName);
    await _prefs.setString(_vehicleModelKey, _vehicleModel);
    notifyListeners();
  }
  Future<void> setObdEnabled(bool value) async { _obdEnabled = value; await _prefs.setBool(_obdEnabledKey, value); notifyListeners(); }
}
