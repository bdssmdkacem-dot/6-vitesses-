import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../driving/drive_history.dart';
import '../driving/drive_history_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../driving/driving_session.dart';
import '../navigation/map_screen.dart';
import '../navigation/navigation_engine.dart';
import '../navigation/navigation_models.dart';
import '../navigation/osrm_route_service.dart';
import '../navigation/osm_traffic_service.dart';
import '../navigation/traffic_sign_engine.dart';
import '../navigation/widgets/navigation_hud_overlay.dart';
import '../settings/app_settings.dart';
import '../sensors/gps_speed_service.dart';
import '../sensors/motion_sensor_service.dart';
import 'models/hud_theme.dart';
import 'widgets/acceleration_bar.dart';
import 'widgets/gear_indicator.dart';
import 'widgets/hud_background.dart';
import 'widgets/rpm_indicator.dart';
import 'widgets/speed_gauge.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key,required this.settings,required this.history});
  final AppSettings settings; final DriveHistory history;
  @override State<HudScreen> createState()=>_HudScreenState();
}
class _HudScreenState extends State<HudScreen> with WidgetsBindingObserver {
  final _session=DrivingSession(),_gpsService=GpsSpeedService(),_motionService=MotionSensorService();
  final _navigationEngine = const NavigationEngine();
  final _trafficService = OsmTrafficService();
  final _trafficEngine = TrafficSignEngine();
  Timer? _trafficTimer;
  DateTime? _lastTrafficFetch;
  LatLng? _lastPosition;
  double _lastHeading = 0;
  List<TrafficSign> _trafficSigns = const [];
  RelevantTrafficSign? _relevantTrafficSign;
  OsrmRoute? _navigationRoute;
  NavigationState? _navigationState;
  StreamSubscription<GpsSample>? _gpsSub; StreamSubscription<MotionSample>? _motionSub; Timer? _gpsWatchdog;
  double _speed=0,_longitudinalAccel=0,_totalAccel=0,_maxSpeed=0,_maxAccel=0,_maxBraking=0; double? _rpm;
  int _gear=0; bool _mirror=false,_ready=false,_gpsStale=true; HudTheme _theme=HudTheme.midnight; HudGaugeStyle _style=HudGaugeStyle.digital;

  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);WidgetsBinding.instance.addPostFrameCallback((_) {if(mounted){_initializeHud();}});}
  Future<void> _initializeHud() async {await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);if(!mounted)return;final permission=await _gpsService.requestLocationPermission();if(!mounted)return;if(permission==LocationPermission.denied){await _showLocationPermissionDenied();}else if(permission==LocationPermission.deniedForever){await _showLocationPermissionBlocked();}if(!mounted)return;await _enterHud();await _startSensors();}
  Future<void> _showLocationPermissionDenied() async {await showDialog<void>(context:context,barrierDismissible:false,builder:(dialogContext)=>AlertDialog(title:const Text('LOCATION REQUIRED'),content:const Text('Location permission is required for GPS speed and driving measurements.'),actions:[TextButton(onPressed:() async {final result=await _gpsService.requestLocationPermission();if(!dialogContext.mounted)return;if(result==LocationPermission.deniedForever){Navigator.pop(dialogContext);await _showLocationPermissionBlocked();}else if(result==LocationPermission.whileInUse||result==LocationPermission.always){Navigator.pop(dialogContext);}},child:const Text('RE-ALLOW LOCATION')),FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('CONTINUE'))]));}
  Future<void> _showLocationPermissionBlocked() async {await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(title:const Text('LOCATION PERMISSION'),content:const Text('Location access is blocked. Open Android app settings and allow Location.'),actions:[TextButton(onPressed:() async {await Geolocator.openAppSettings();if(dialogContext.mounted)Navigator.pop(dialogContext);},child:const Text('APP SETTINGS')),FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('CLOSE'))]));}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_enterHud();}
  Future<void> _enterHud()async{await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);await WakelockPlus.enable();}
  Future<void> _startSensors()async{
    _gpsSub ??= _gpsService.samples.listen((sample){if(!mounted)return;if(!sample.isStale){_motionService.updateVehicleSpeed(sample.speedKmh,sample.timestamp);}setState((){if(!sample.isStale){
          _speed=sample.speedKmh;_longitudinalAccel=sample.longitudinalAcceleration;
          _lastPosition = sample.position;
          _lastHeading = sample.headingDegrees;
          if (_navigationRoute != null && sample.position != null) {
            _navigationState = _navigationEngine.update(route: _navigationRoute!, position: sample.position!);
          }if(_speed>_maxSpeed)_maxSpeed=_speed;if(_longitudinalAccel>_maxAccel)_maxAccel=_longitudinalAccel;if(_longitudinalAccel<_maxBraking)_maxBraking=_longitudinalAccel;}_gpsStale=sample.isStale;});if(_session.active&&!sample.isStale)_session.addSample(speedKmh:sample.speedKmh,acceleration:sample.longitudinalAcceleration,timestamp:sample.timestamp);});
    _motionSub ??= _motionService.samples.listen((sample){if(!mounted)return;setState((){_longitudinalAccel=sample.longitudinalAcceleration;_totalAccel=sample.totalAcceleration;if(sample.longitudinalAcceleration>_maxAccel)_maxAccel=sample.longitudinalAcceleration;if(sample.longitudinalAcceleration<_maxBraking)_maxBraking=sample.longitudinalAcceleration;});});
    _motionService.start();await _gpsService.start();
    _trafficTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 5), (_) { _refreshTrafficSigns(); });
    _gpsWatchdog?.cancel();_gpsWatchdog=Timer.periodic(const Duration(seconds:1),(_){if(!mounted)return;final stale=_gpsService.isStale;if(stale!=_gpsStale)setState(()=>_gpsStale=stale);if(stale)_gpsService.start();});if(mounted)setState(()=>_ready=true);
  }
  Future<void> _refreshTrafficSigns() async {
    final position = _lastPosition;
    if (!_session.active || position == null) return;
    final now = DateTime.now();
    if (_lastTrafficFetch != null && now.difference(_lastTrafficFetch!) < const Duration(seconds: 20)) return;
    _lastTrafficFetch = now;
    try {
      final signs = await _trafficService.nearby(center: position);
      final relevant = _trafficEngine.findRelevant(vehiclePosition: position, headingDegrees: _lastHeading, signs: signs);
      if (!mounted) return;
      setState(() { _trafficSigns = signs; _relevantTrafficSign = relevant.isEmpty ? null : relevant.first; });
    } catch (_) {
      // Navigation and HUD remain fully functional if OSM traffic data is unavailable.
    }
  }

  void _showGpsDiagnostics() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('GPS DIAGNOSTICS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Permission: ${_gpsService.permission.name}'),
              Text('Status: ${_gpsService.status}'),
              if (_gpsService.lastError != null)
                Text('Error: ${_gpsService.lastError}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _gpsService.refreshPermission();
                setDialog(() {});
              },
              child: const Text('REFRESH'),
            ),
            TextButton(
              onPressed: () async {
                final permission = await _gpsService.requestLocationPermission();
                setDialog(() {});
                if (permission == LocationPermission.whileInUse ||
                    permission == LocationPermission.always) {
                  _gpsService.start();
                }
              },
              child: const Text('RE-ALLOW LOCATION'),
            ),
            TextButton(
              onPressed: () => Geolocator.openLocationSettings(),
              child: const Text('LOCATION SETTINGS'),
            ),
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text('APP SETTINGS'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }
  void _startDrive(){_session.start();setState((){_maxSpeed=0;_maxAccel=0;_maxBraking=0;});}
  Future<void> _stopDrive()async{final record=_session.stop();await widget.history.add(record);if(mounted)setState((){});}
  void _settings() {
    if (_session.active) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _theme.background,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          final themes = HudTheme.all.map<Widget>((theme) => ChoiceChip(
            label: Text(theme.name), selected: _theme == theme,
            onSelected: (_) async {
              await widget.settings.setTheme(theme);
              await widget.settings.setGauge(theme.defaultGauge);
              if (!mounted) return;
              setState(() { _theme = theme; _style = theme.defaultGauge; });
              setSheet(() {});
            },
          )).toList();

          final gauges = HudGaugeStyle.values.map<Widget>((style) => ChoiceChip(
            label: Text(style.name.toUpperCase()), selected: _style == style,
            onSelected: (_) async {
              await widget.settings.setGauge(style);
              if (!mounted) return;
              setState(() => _style = style);
              setSheet(() {});
            },
          )).toList();

          final gears = List<Widget>.generate(7, (index) => ChoiceChip(
            label: Text(index == 0 ? 'N' : '$index'),
            selected: _gear == index,
            onSelected: (_) async {
              await widget.settings.setGear(index);
              if (!mounted) return;
              setState(() => _gear = index);
              setSheet(() {});
            },
          ));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('HUD SETTINGS', style: TextStyle(color: _theme.accent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: themes),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: gauges),
                const SizedBox(height: 8),
                GearIndicator(gear: _gear, theme: _theme),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: gears),
                ListTile(
                  title: Text(widget.settings.vehicleName),
                  subtitle: Text(widget.settings.vehicleModel.isEmpty ? 'Vehicle profile' : widget.settings.vehicleModel),
                  leading: const Icon(Icons.directions_car),
                  onTap: () async {
                    final name = TextEditingController(text: widget.settings.vehicleName);
                    final model = TextEditingController(text: widget.settings.vehicleModel);
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Vehicle profile'),
                        content: Column(mainAxisSize: MainAxisSize.min, children: [
                          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                          TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
                        ]),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () async {
                              await widget.settings.setVehicle(name: name.text, model: model.text);
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              setSheet(() {});
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    name.dispose();
                    model.dispose();
                  },
                ),
                DropdownButtonFormField<SpeedUnit>(
                  initialValue: widget.settings.unit,
                  decoration: const InputDecoration(labelText: 'Speed unit'),
                  items: const [
                    DropdownMenuItem(value: SpeedUnit.kmh, child: Text('km/h')),
                    DropdownMenuItem(value: SpeedUnit.mph, child: Text('mph')),
                  ],
                  onChanged: (value) async {
                    if (value != null) {
                      await widget.settings.setUnit(value);
                      setSheet(() {});
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Gauge limit: ${widget.settings.speedLimit.toStringAsFixed(0)}'),
                  subtitle: Slider(
                    min: 60, max: 360, divisions: 30,
                    value: widget.settings.speedLimit.clamp(60.0, 360.0).toDouble(),
                    onChanged: (value) async {
                      await widget.settings.setSpeedLimit(value);
                      setSheet(() {});
                    },
                  ),
                ),
                SwitchListTile(title: const Text('Animations'), subtitle: const Text('Smooth speed, gauge and background motion'), value: widget.settings.animations, onChanged: (value) async { await widget.settings.setAnimations(value); setSheet(() {}); }),
                SwitchListTile(title: const Text('RPM indicator'), subtitle: Text(widget.settings.obdEnabled ? 'Waiting for OBD-II telemetry' : 'Ready for OBD-II'), value: widget.settings.showRpm, onChanged: (value) async { await widget.settings.setShowRpm(value); setSheet(() {}); }),
                SwitchListTile(title: const Text('Compact HUD'), subtitle: const Text('Reduce secondary information while driving'), value: widget.settings.compact, onChanged: (value) async { await widget.settings.setCompact(value); setSheet(() {}); }),
                SwitchListTile(title: const Text('OBD-II ready'), subtitle: const Text('GPS remains the fallback source until a Bluetooth adapter is connected.'), value: widget.settings.obdEnabled, onChanged: (value) async { await widget.settings.setObdEnabled(value); setSheet(() {}); }),
                SwitchListTile(title: const Text('Mirror HUD'), value: _mirror, onChanged: (value) async { await widget.settings.setMirror(value); if (!mounted) return; setState(() => _mirror = value); setSheet(() {}); }),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: () { _startDrive(); Navigator.pop(context); }, icon: const Icon(Icons.play_arrow), label: const Text('START DRIVE')),
              ],
            ),
          );
        },
      ),
    );
  }

  @override Widget build(BuildContext context){
    _theme=widget.settings.theme;_style=widget.settings.gauge;_mirror=widget.settings.mirror;_gear=widget.settings.gear;
    final unitLabel=widget.settings.unit==SpeedUnit.kmh?'km/h':'mph',showRpm=widget.settings.showRpm&&_theme.showRpm,compact=widget.settings.compact;

    final navigationActive = _session.active && _navigationState != null;
    final hudLayer=Stack(fit:StackFit.expand,children:[
      HudBackground(theme:_theme,animate:widget.settings.animations),
      SafeArea(child:Stack(children:[
        Center(child:SpeedGauge(speed:widget.settings.toDisplaySpeed(_speed),maxSpeed:widget.settings.toDisplaySpeed(widget.settings.speedLimit),style:_style,theme:_theme,unitLabel:unitLabel,animate:widget.settings.animations)),
        if(showRpm)Positioned(top:navigationActive ? 8 : (compact?8:42),left:0,right:0,child:Center(child:RpmIndicator(rpm:_rpm,theme:_theme,style:_theme.rpmStyle,animate:widget.settings.animations))),
        if(navigationActive)NavigationHudOverlay(state:_navigationState!,accent:_theme.accent,secondary:_theme.secondary,trafficSign:_relevantTrafficSign),
        Positioned(left:18,top:14,child:GestureDetector(onTap:_showGpsDiagnostics,child:Row(children:[Icon(_gpsStale?Icons.gps_off:Icons.gps_fixed,size:15,color:_gpsStale?Colors.redAccent:_theme.secondary),const SizedBox(width:6),Text(_gpsStale?'GPS LOST':'GPS LOCK',style:TextStyle(color:_gpsStale?Colors.redAccent:_theme.secondary,fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(width:6),Text(_gpsService.status,style:TextStyle(color:_theme.secondary,fontSize:10))]))),
        Positioned(right:18,top:12,child:GearIndicator(gear:_gear,theme:_theme,enabled:!_session.active)),
        if(!compact)Positioned(left:18,bottom:14,child:Row(children:[
          _Metric('ACCEL','${_longitudinalAccel.toStringAsFixed(1)} m/s²'),const SizedBox(width:18),AccelerationBar(value:_longitudinalAccel,theme:_theme),const SizedBox(width:18),_Metric('G-FORCE','${(_totalAccel/9.80665).toStringAsFixed(2)} G'),const SizedBox(width:18),_Metric('MAX','${widget.settings.toDisplaySpeed(_maxSpeed).toStringAsFixed(0)} $unitLabel'),
          if(_session.active)...[const SizedBox(width:18),_Metric('TRIP','${_session.distanceKm.toStringAsFixed(1)} km')],
        ])),
        if(!compact)Positioned(right:18,bottom:14,child:Row(children:[_Metric('BRAKE MAX','${_maxBraking.toStringAsFixed(1)} m/s²')])),
        if(!_ready)Center(child:Text('STARTING SENSORS...',style:TextStyle(color:_theme.secondary))),
      ])),
    ]);

    return Scaffold(
      backgroundColor:_theme.background,
      body:Stack(fit:StackFit.expand,children:[
        Transform(
          alignment:Alignment.center,
          transform:Matrix4.diagonal3Values(_mirror?-1:1,1,1),
          child:hudLayer,
        ),
        SafeArea(child:Stack(children:[
          if(!_session.active)Positioned(right:132,top:8,child:IconButton(onPressed:() async {
            await Navigator.of(context).push(MaterialPageRoute(builder:(_) => MapScreen(onRouteReady:(route) {
              if (!mounted) return;
              setState(() { _navigationRoute = route; _navigationState = null; });
            })));
          },icon:Icon(Icons.map,color:_theme.accent),tooltip:'Map')),
          if(!_session.active)Positioned(right:86,top:8,child:IconButton(onPressed:_settings,icon:Icon(Icons.tune,color:_theme.accent),tooltip:'Settings')),
          if(_session.active)Positioned(right:18,top:10,child:FilledButton.icon(onPressed:_stopDrive,icon:const Icon(Icons.stop,size:16),label:const Text('STOP'))),
          if(!_session.active&&!compact)Positioned(right:18,bottom:14,child:IconButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DriveHistoryScreen(history:widget.history))),icon:Icon(Icons.history,color:_theme.accent),tooltip:'History')),
        ])),
      ]),
    );
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_gpsWatchdog?.cancel();_trafficTimer?.cancel();_gpsSub?.cancel();_motionSub?.cancel();_gpsService.dispose();_motionService.dispose();_trafficService.dispose();_session.dispose();WakelockPlus.disable();SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);SystemChrome.setPreferredOrientations(DeviceOrientation.values);super.dispose();}
}
class _Metric extends StatelessWidget {
  const _Metric(this.label,this.value); final String label,value;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10)),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700))]);
}
