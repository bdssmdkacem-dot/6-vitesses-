import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../hud/models/hud_theme.dart';

enum SpeedUnit { kmh, mph }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);
  final SharedPreferences _prefs;
  static const _themeKey='hud_theme', _gaugeKey='hud_gauge', _gtLayoutKey='gt_layout', _mirrorKey='hud_mirror', _gearKey='hud_gear', _unitKey='speed_unit', _limitKey='speed_limit', _vehicleNameKey='vehicle_name', _vehicleModelKey='vehicle_model', _obdEnabledKey='obd_enabled', _animationsKey='hud_animations', _rpmKey='hud_rpm', _compactKey='hud_compact';

  HudTheme _theme=HudTheme.midnight;
  HudGaugeStyle _gauge=HudGaugeStyle.digital;
  GtLayout _gtLayout=GtLayout.nav;
  bool _mirror=false,_obdEnabled=false,_animations=true,_showRpm=true,_compact=false;
  int _gear=0;
  SpeedUnit _unit=SpeedUnit.kmh;
  double _speedLimit=240;
  String _vehicleName='My Car',_vehicleModel='';

  static Future<AppSettings> load() async {
    final prefs=await SharedPreferences.getInstance();
    final s=AppSettings._(prefs);
    s._theme=_themeFromIndex(prefs.getInt(_themeKey)??0);
    s._gauge=HudGaugeStyle.values[(prefs.getInt(_gaugeKey)??0).clamp(0,HudGaugeStyle.values.length-1).toInt()];
    s._gtLayout=GtLayout.values[(prefs.getInt(_gtLayoutKey)??0).clamp(0,GtLayout.values.length-1).toInt()];
    s._mirror=prefs.getBool(_mirrorKey)??false;
    s._gear=(prefs.getInt(_gearKey)??0).clamp(0,6).toInt();
    s._unit=SpeedUnit.values[(prefs.getInt(_unitKey)??0).clamp(0,SpeedUnit.values.length-1).toInt()];
    s._speedLimit=prefs.getDouble(_limitKey)??240;
    s._vehicleName=prefs.getString(_vehicleNameKey)??'My Car';
    s._vehicleModel=prefs.getString(_vehicleModelKey)??'';
    s._obdEnabled=prefs.getBool(_obdEnabledKey)??false;
    s._animations=prefs.getBool(_animationsKey)??true;
    s._showRpm=prefs.getBool(_rpmKey)??true;
    s._compact=prefs.getBool(_compactKey)??false;
    return s;
  }
  static HudTheme _themeFromIndex(int i)=>HudTheme.all[i.clamp(0,HudTheme.all.length-1).toInt()];
  HudTheme get theme=>_theme; HudGaugeStyle get gauge=>_gauge; GtLayout get gtLayout=>_gtLayout; bool get mirror=>_mirror; int get gear=>_gear; SpeedUnit get unit=>_unit; double get speedLimit=>_speedLimit; String get vehicleName=>_vehicleName; String get vehicleModel=>_vehicleModel; bool get obdEnabled=>_obdEnabled; bool get animations=>_animations; bool get showRpm=>_showRpm; bool get compact=>_compact;
  double toDisplaySpeed(double kmh)=>_unit==SpeedUnit.kmh?kmh:kmh*0.621371;
  Future<void> setTheme(HudTheme v)async{_theme=v;await _prefs.setInt(_themeKey,HudTheme.all.indexOf(v));notifyListeners();}
  Future<void> setGauge(HudGaugeStyle v)async{_gauge=v;await _prefs.setInt(_gaugeKey,v.index);notifyListeners();}
  Future<void> setGtLayout(GtLayout v)async{_gtLayout=v;await _prefs.setInt(_gtLayoutKey,v.index);notifyListeners();}
  Future<void> setMirror(bool v)async{_mirror=v;await _prefs.setBool(_mirrorKey,v);notifyListeners();}
  Future<void> setGear(int v)async{_gear=v.clamp(0,6).toInt();await _prefs.setInt(_gearKey,_gear);notifyListeners();}
  Future<void> setUnit(SpeedUnit v)async{_unit=v;await _prefs.setInt(_unitKey,v.index);notifyListeners();}
  Future<void> setSpeedLimit(double v)async{_speedLimit=v.clamp(60,360).toDouble();await _prefs.setDouble(_limitKey,_speedLimit);notifyListeners();}
  Future<void> setVehicle({required String name,required String model})async{_vehicleName=name.trim().isEmpty?'My Car':name.trim();_vehicleModel=model.trim();await _prefs.setString(_vehicleNameKey,_vehicleName);await _prefs.setString(_vehicleModelKey,_vehicleModel);notifyListeners();}
  Future<void> setObdEnabled(bool v)async{_obdEnabled=v;await _prefs.setBool(_obdEnabledKey,v);notifyListeners();}
  Future<void> setAnimations(bool v)async{_animations=v;await _prefs.setBool(_animationsKey,v);notifyListeners();}
  Future<void> setShowRpm(bool v)async{_showRpm=v;await _prefs.setBool(_rpmKey,v);notifyListeners();}
  Future<void> setCompact(bool v)async{_compact=v;await _prefs.setBool(_compactKey,v);notifyListeners();}
}
