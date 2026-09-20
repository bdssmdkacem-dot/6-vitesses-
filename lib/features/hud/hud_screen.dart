import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../driving/drive_history.dart';
import '../driving/drive_history_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../driving/driving_session.dart';
import '../driving/obd/elm327_session.dart';
import '../driving/obd/flutter_classic_obd_transport.dart';
import '../driving/obd/obd_telemetry.dart';
import '../navigation/map_screen.dart';
import '../navigation/navigation_engine.dart';
import '../navigation/navigation_models.dart';
import '../navigation/navigation_session_controller.dart';
import '../navigation/osrm_route_service.dart';
import '../navigation/osm_traffic_service.dart';
import '../navigation/traffic_sign_engine.dart';
import '../navigation/widgets/navigation_hud_overlay.dart';
import '../settings/app_settings.dart';
import '../sensors/gps_speed_service.dart';
import '../sensors/motion_sensor_service.dart';
import '../sensors/sensor_fusion_service.dart';
import '../sensors/sensor_performance_monitor.dart';
import 'models/hud_theme.dart';
import 'widgets/acceleration_bar.dart';
import 'widgets/gear_indicator.dart';
import 'widgets/hud_background.dart';
import 'widgets/rpm_indicator.dart';
import 'widgets/speed_gauge.dart';
import 'widgets/gt_layout_engine.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key,required this.settings,required this.history});
  final AppSettings settings; final DriveHistory history;
  @override State<HudScreen> createState()=>_HudScreenState();
}
class _HudScreenState extends State<HudScreen> with WidgetsBindingObserver {
  final _session=DrivingSession(),_gpsService=GpsSpeedService(),_motionService=MotionSensorService();
  final _obdSession = Elm327Session(FlutterClassicObdTransport());
  final _fusionService = SensorFusionService();
  final _performanceMonitor = SensorPerformanceMonitor();
  final _navigationEngine = const NavigationEngine();
  final _navigationSession = NavigationSessionController();
  final _routeService = OsrmRouteService();
  final _trafficService = OsmTrafficService();
  final _trafficEngine = TrafficSignEngine();
  Timer? _trafficTimer;
  DateTime? _lastTrafficFetch;
  LatLng? _lastPosition;
  double _lastHeading = 0;
  List<RelevantTrafficSign> _relevantTrafficSigns = const [];
  
  String? _navigationMessage;
  OsrmRoute? _navigationRoute;
  NavigationState? _navigationState;
  StreamSubscription<GpsSample>? _gpsSub; StreamSubscription<MotionSample>? _motionSub; StreamSubscription<ObdTelemetry>? _obdSub; Timer? _gpsWatchdog;
  double _speed=0,_longitudinalAccel=0,_totalAccel=0,_maxSpeed=0,_maxAccel=0,_maxBraking=0; double? _rpm;
  SensorFusionSample _fusion = SensorFusionSample(speedKmh:0,longitudinalAcceleration:0,lateralAcceleration:0,totalAcceleration:0,speedConfidence:0,accelerationConfidence:0,overallConfidence:0,source:SensorSource.unavailable,timestamp:DateTime.fromMillisecondsSinceEpoch(0));
  bool _mirror=false,_ready=false,_gpsStale=true,_obdConnecting=false; HudTheme _theme=HudTheme.midnight; HudGaugeStyle _style=HudGaugeStyle.digital;

  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);WidgetsBinding.instance.addPostFrameCallback((_) {if(mounted){_initializeHud();}});}
  Future<void> _initializeHud() async {await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);if(!mounted)return;final permission=await _gpsService.refreshPermission();if(!mounted)return;if(permission==LocationPermission.denied){final requested=await _gpsService.requestLocationPermission();if(requested==LocationPermission.denied){await _showLocationPermissionDenied();}else if(requested==LocationPermission.deniedForever){await _showLocationPermissionBlocked();}}else if(permission==LocationPermission.deniedForever){await _showLocationPermissionBlocked();}if(!mounted)return;await _enterHud();await _startSensors();}
  Future<void> _showLocationPermissionDenied() async {await showDialog<void>(context:context,barrierDismissible:false,builder:(dialogContext)=>AlertDialog(title:const Text('LOCATION REQUIRED'),content:const Text('Location permission is required for GPS speed and driving measurements.'),actions:[TextButton(onPressed:() async {final result=await _gpsService.requestLocationPermission();if(!dialogContext.mounted)return;if(result==LocationPermission.deniedForever){Navigator.pop(dialogContext);await _showLocationPermissionBlocked();}else if(result==LocationPermission.whileInUse||result==LocationPermission.always){Navigator.pop(dialogContext);await _gpsService.start();}else {await _gpsService.refreshPermission();}},child:const Text('RE-ALLOW LOCATION')),FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('CONTINUE'))]));}
  Future<void> _showLocationPermissionBlocked() async {await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(title:const Text('LOCATION PERMISSION'),content:const Text('Location access is blocked. Open Android app settings and allow Location.'),actions:[TextButton(onPressed:() async {await Geolocator.openAppSettings();if(dialogContext.mounted)Navigator.pop(dialogContext);},child:const Text('APP SETTINGS')),FilledButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('CLOSE'))]));}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed){
      _enterHud();
      unawaited(_recoverLocationPermission());
    }
  }
  Future<void> _recoverLocationPermission() async {
    final permission = await _gpsService.refreshPermission();
    if (!mounted) return;
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      await _gpsService.start();
      return;
    }
    if (permission == LocationPermission.denied) {
      final requested = await _gpsService.requestLocationPermission();
      if (!mounted) return;
      if (requested == LocationPermission.whileInUse || requested == LocationPermission.always) {
        await _gpsService.start();
      }
    }
  }
  Future<void> _enterHud()async{await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);await WakelockPlus.enable();}
  Future<void> _syncObd() async {
    if (!widget.settings.obdEnabled || widget.settings.obdAddress.trim().isEmpty) {
      await _obdSession.disconnect();
      return;
    }
    if (_obdSession.connected || _obdConnecting) return;
    _obdConnecting = true;
    try {
      await _obdSession.connectToAddress(widget.settings.obdAddress.trim());
      _obdSession.startTelemetryPolling();
    } catch (_) {
      await _obdSession.disconnect();
    } finally {
      _obdConnecting = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _startSensors()async{
    _obdSub ??= _obdSession.telemetry.listen((sample){
      if (!mounted) return;
      final fusion = _fusionService.updateObd(sample);
      setState(() {
        _fusion = fusion;
        if (sample.rpm != null) _rpm = sample.rpm;
        if (sample.vehicleSpeedKmh != null && _gpsStale && _session.active) {
          _session.addSample(
            speedKmh: fusion.speedKmh,
            acceleration: fusion.longitudinalAcceleration,
            lateralAcceleration: fusion.lateralAcceleration,
            timestamp: fusion.timestamp,
          );
        }
      });
    });
    _gpsSub ??= _gpsService.samples.listen((sample){
      final stopwatch = Stopwatch()..start();
      if (!mounted) return;
      final fusion = _fusionService.updateGps(sample);
      if (!sample.isStale) {
        _motionService.updateVehicleSpeed(fusion.speedKmh, sample.timestamp);
      }
      setState(() {
        _fusion = fusion;
        if (!sample.isStale) {
          _speed = fusion.speedKmh;
          _longitudinalAccel = fusion.longitudinalAcceleration;
          _lastPosition = sample.position;
          _lastHeading = sample.headingDegrees;
          if (_navigationRoute != null && sample.position != null) {
            _navigationState = _navigationEngine.update(
              route: _navigationRoute!,
              position: sample.position!,
              speedKmh: fusion.speedKmh,
              headingDegrees: sample.headingDegrees,
              previousRouteProgressMeters: _navigationState?.routeProgressMeters,
              previousRouteSegmentIndex: _navigationState?.routeSegmentIndex,
            );
            _navigationSession.update(_navigationState!, sample.timestamp);
            if (_navigationSession.status == NavigationSessionStatus.arrived) {
              _navigationMessage = 'ARRIVED';
            } else if (_navigationSession.shouldReroute(sample.timestamp)) {
              unawaited(_rerouteFromCurrentPosition(sample.position!, sample.timestamp));
            } else if (!_navigationState!.offRoute &&
                _navigationSession.status == NavigationSessionStatus.navigating) {
              _navigationMessage = null;
            }
          }
          if (_speed > _maxSpeed) _maxSpeed = _speed;
          if (_longitudinalAccel > _maxAccel) _maxAccel = _longitudinalAccel;
          if (_longitudinalAccel < _maxBraking) _maxBraking = _longitudinalAccel;
        }
        _gpsStale = sample.isStale;
      });
      if (_session.active && !sample.isStale) {
        _session.addSample(
          speedKmh: fusion.speedKmh,
          acceleration: fusion.longitudinalAcceleration,
          lateralAcceleration: fusion.lateralAcceleration,
          timestamp: sample.timestamp,
        );
      }
      stopwatch.stop();
      _performanceMonitor.recordCallback(stopwatch.elapsed);
    });
    _motionSub ??= _motionService.samples.listen((sample){
      final stopwatch = Stopwatch()..start();
      if (!mounted) return;
      final fusion = _fusionService.updateMotion(sample);
      setState(() {
        _fusion = fusion;
        _speed = fusion.speedKmh;
        _longitudinalAccel = fusion.longitudinalAcceleration;
        _totalAccel = fusion.totalAcceleration;
        if (fusion.longitudinalAcceleration > _maxAccel) _maxAccel = fusion.longitudinalAcceleration;
        if (fusion.longitudinalAcceleration < _maxBraking) _maxBraking = fusion.longitudinalAcceleration;
      });
      stopwatch.stop();
      _performanceMonitor.recordCallback(stopwatch.elapsed);
    });
    _motionService.start();await _gpsService.start();await _syncObd();
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
      final relevant = _trafficEngine.findRelevant(vehiclePosition: position, headingDegrees: _lastHeading, vehicleSpeedKmh: _speed, signs: signs, route: _navigationRoute?.geometry,
        vehicleRouteProgressMeters: _navigationState?.routeProgressMeters);
      if (!mounted) return;
      setState(() { _relevantTrafficSigns = relevant.take(3).toList(growable: false); });
    } catch (_) {}
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
              Text('Source: ${_sourceLabel(_fusion.source)}'),
              Text('Confidence: ${(_fusion.overallConfidence * 100).round()}%'),
              Text('GPS jumps rejected: ${_gpsService.jumpRejections}'),
              Text('IMU noise confidence: ${(_fusion.accelerationConfidence * 100).round()}%'),
              Text('Sensor callbacks: ${_performanceMonitor.snapshot().events}'),
              if (_gpsService.lastError != null) Text('Error: ${_gpsService.lastError}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () async {await _gpsService.refreshPermission();setDialog(() {});},child: const Text('REFRESH')),
            TextButton(onPressed: () async {final permission=await _gpsService.requestLocationPermission();setDialog(() {});if(permission==LocationPermission.whileInUse||permission==LocationPermission.always){_gpsService.start();}},child: const Text('RE-ALLOW LOCATION')),
            TextButton(onPressed: () => Geolocator.openLocationSettings(),child: const Text('LOCATION SETTINGS')),
            TextButton(onPressed: () => Geolocator.openAppSettings(),child: const Text('APP SETTINGS')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext),child: const Text('CLOSE')),
          ],
        ),
      ),
    );
  }
  void _startDrive(){_session.start();setState((){_maxSpeed=0;_maxAccel=0;_maxBraking=0;_navigationMessage=null;});}
  Future<void> _rerouteFromCurrentPosition(LatLng position, DateTime attemptTime) async {
    final destination = _navigationRoute?.destination;
    if (destination == null || _navigationSession.rerouteInProgress || !_session.active) return;
    _navigationSession.beginReroute(attemptTime);
    if (mounted) setState(() => _navigationMessage = 'RE-ROUTING…');
    try {
      final route = await _routeService.route(start: position, destination: destination);
      if (!mounted || !_session.active) return;
      final nextState = _navigationEngine.update(route: route,position: position,speedKmh: _speed,headingDegrees: _lastHeading);
      _navigationSession.rerouteSucceeded(route);
      setState(() {_navigationRoute=route;_navigationState=nextState;_navigationMessage=null;});
      _lastTrafficFetch=null;
    } catch (_) {
      _navigationSession.rerouteFailed();
      if (mounted) setState(() => _navigationMessage='OFF ROUTE • NETWORK UNAVAILABLE');
    }
  }

  Future<void> _stopDrive()async{final record=_session.stop();await widget.history.add(record);_navigationSession.stop();if(mounted)setState((){_navigationMessage=null;});}
  void _settings() {
    if (_session.active) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _theme.background,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          final themes = HudTheme.all.map<Widget>((theme) => ChoiceChip(label: Text(theme.name), selected: _theme == theme,onSelected: (_) async {await widget.settings.setTheme(theme);await widget.settings.setGauge(theme.defaultGauge);if (!mounted) return;setState(() {_theme=theme;_style=theme.defaultGauge;});setSheet(() {});},)).toList();
          final gauges = HudGaugeStyle.values.map<Widget>((style) => ChoiceChip(label: Text(_gaugeLabel(style)), selected: _style == style,onSelected: (_) async {await widget.settings.setGauge(style);if (!mounted) return;setState(() => _style=style);setSheet(() {});},)).toList();
          final gtLayouts = GtLayout.values.map<Widget>((layout) => ChoiceChip(label: Text(GtLayoutEngine.label(layout)), selected: widget.settings.gtLayout == layout,onSelected: (_) async {await widget.settings.setGtLayout(layout);if (!mounted) return;setSheet(() {});},)).toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20,20,20,28),
            child: Column(mainAxisSize: MainAxisSize.min,children:[
              Text('HUD SETTINGS',style: TextStyle(color:_theme.accent,fontSize:18,fontWeight:FontWeight.bold)),
              const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:themes),
              const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:gauges),
              if (_style == HudGaugeStyle.digitalGt) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DIGITAL GT LAYOUT',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: gtLayouts),
              ],
              const SizedBox(height:8),
              ListTile(leading:Icon(Icons.settings_ethernet,color:_theme.accent),title:const Text('Automatic gear'),subtitle:const Text('Estimated from vehicle speed. OBD-II can provide true transmission data later.'),trailing:GearIndicator(gear:_estimatedGear(_speed),theme:_theme)),
              ListTile(title:Text(widget.settings.vehicleName),subtitle:Text(widget.settings.vehicleModel.isEmpty?'Vehicle profile':widget.settings.vehicleModel),leading:const Icon(Icons.directions_car),onTap:() async {final name=TextEditingController(text:widget.settings.vehicleName);final model=TextEditingController(text:widget.settings.vehicleModel);await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(title:const Text('Vehicle profile'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),TextField(controller:model,decoration:const InputDecoration(labelText:'Model'))]),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:() async {await widget.settings.setVehicle(name:name.text,model:model.text);if(dialogContext.mounted)Navigator.pop(dialogContext);setSheet(() {});},child:const Text('Save'))],));name.dispose();model.dispose();}),
              DropdownButtonFormField<SpeedUnit>(initialValue:widget.settings.unit,decoration:const InputDecoration(labelText:'Speed unit'),items:const[DropdownMenuItem(value:SpeedUnit.kmh,child:Text('km/h')),DropdownMenuItem(value:SpeedUnit.mph,child:Text('mph'))],onChanged:(value) async {if(value!=null){await widget.settings.setUnit(value);setSheet((){});}}),
              const SizedBox(height:8),
              ListTile(title:Text('Gauge limit: ${widget.settings.speedLimit.toStringAsFixed(0)}'),subtitle:Slider(min:60,max:360,divisions:30,value:widget.settings.speedLimit.clamp(60.0,360.0).toDouble(),onChanged:(value) async {await widget.settings.setSpeedLimit(value);setSheet((){});})),
              SwitchListTile(title:const Text('Animations'),subtitle:const Text('Smooth speed, gauge and background motion'),value:widget.settings.animations,onChanged:(value) async {await widget.settings.setAnimations(value);setSheet((){});}),
              SwitchListTile(title:const Text('RPM indicator'),subtitle:Text(widget.settings.obdEnabled?'Waiting for OBD-II telemetry':'Ready for OBD-II'),value:widget.settings.showRpm,onChanged:(value) async {await widget.settings.setShowRpm(value);setSheet((){});}),
              SwitchListTile(title:const Text('Compact HUD'),subtitle:const Text('Reduce secondary information while driving'),value:widget.settings.compact,onChanged:(value) async {await widget.settings.setCompact(value);setSheet((){});}),
              SwitchListTile(title:const Text('OBD-II ready'),subtitle:Text(widget.settings.obdAddress.isEmpty?'GPS remains the fallback until an adapter address is configured.':(_obdSession.connected?'OBD-II connected':'OBD-II will connect when available.')),value:widget.settings.obdEnabled,onChanged:(value) async {await widget.settings.setObdEnabled(value);await _syncObd();setSheet((){});}),
              TextFormField(initialValue:widget.settings.obdAddress,decoration:const InputDecoration(labelText:'OBD-II Bluetooth address',hintText:'Example: 00:1D:A5:68:98:8B'),onChanged:(value) async {await widget.settings.setObdAddress(value);}),
              SwitchListTile(title:const Text('Mirror HUD'),value:_mirror,onChanged:(value) async {await widget.settings.setMirror(value);if(!mounted)return;setState(()=>_mirror=value);setSheet((){});}),
              const SizedBox(height:8),
              FilledButton.icon(onPressed:(){_startDrive();Navigator.pop(context);},icon:const Icon(Icons.play_arrow),label:const Text('START DRIVE')),
            ]),
          );
        },
      ),
    );
  }

  @override Widget build(BuildContext context){
    _theme=widget.settings.theme;_style=widget.settings.gauge;_mirror=widget.settings.mirror;
    final unitLabel=widget.settings.unit==SpeedUnit.kmh?'km/h':'mph',showRpm=widget.settings.showRpm&&_theme.showRpm,compact=widget.settings.compact;
    final gtEnabled=_style==HudGaugeStyle.digitalGt;
    final gtLayout=widget.settings.gtLayout;final gtSpec=GtLayoutEngine.spec(gtLayout);
    final displayGear=_estimatedGear(_speed);
    final navigationActive=_session.active&&_navigationState!=null;
    final hudLayer=Stack(fit:StackFit.expand,children:[
      HudBackground(theme:_theme,animate:widget.settings.animations),
      SafeArea(child:Stack(children:[
        Align(
          alignment: Alignment.center,
          child: gtEnabled && navigationActive
              ? SizedBox(
                  width: 400,
                  child: SpeedGauge(
                    speed: widget.settings.toDisplaySpeed(_speed),
                    maxSpeed: widget.settings.toDisplaySpeed(widget.settings.speedLimit),
                    style: _style,
                    theme: _theme,
                    unitLabel: unitLabel,
                    animate: widget.settings.animations,
                    gtLayout: gtLayout,
                    gForce: _totalAccel / 9.80665,
                    tripDistanceKm: _session.distanceKm,
                    longitudinalAccel: _longitudinalAccel,
                    gear: _estimatedGear(_speed),
                  ),
                )
              : SpeedGauge(
                  speed: widget.settings.toDisplaySpeed(_speed),
                  maxSpeed: widget.settings.toDisplaySpeed(widget.settings.speedLimit),
                  style: _style,
                  theme: _theme,
                  unitLabel: unitLabel,
                  animate: widget.settings.animations,
                ),
        ),
        if(showRpm)Positioned(top:navigationActive?8:(compact?8:42),left:0,right:0,child:Center(child:RpmIndicator(rpm:_rpm,theme:_theme,style:_theme.rpmStyle,animate:widget.settings.animations))),
        if(_relevantTrafficSigns.isNotEmpty)Positioned(left:14,top:0,bottom:0,child:Center(child:_TrafficSignRail(signs:gtEnabled&&!gtSpec.showFullSignRail?_relevantTrafficSigns.take(1).toList(growable:false):_relevantTrafficSigns,theme:_theme))),
        if(navigationActive)NavigationHudOverlay(state:_navigationState!,accent:_theme.accent,secondary:_theme.secondary,message:_navigationMessage,style:_style,compact:gtEnabled&&gtSpec.compactNavigation,showEta:!gtEnabled||gtSpec.showEta,showRoadName:!gtEnabled||gtSpec.showRoadName),
        Positioned(left:18,top:14,child:GestureDetector(onTap:_showGpsDiagnostics,child:Row(children:[Icon(_gpsStale?Icons.gps_off:Icons.gps_fixed,size:15,color:_gpsStale?Colors.redAccent:_theme.secondary),const SizedBox(width:6),Text(_gpsStale?'GPS LOST':'GPS LOCK',style:TextStyle(color:_gpsStale?Colors.redAccent:_theme.secondary,fontSize:12,fontWeight:FontWeight.w700)),const SizedBox(width:6),Text(_gpsService.status,style:TextStyle(color:_theme.secondary,fontSize:10))]))),
        Positioned(left:18,top:34,child:Row(children:[
          Icon(_sourceIcon(_fusion.source),size:13,color:_sourceColor(_fusion.source,_theme)),
          const SizedBox(width:5),
          Text('${_sourceLabel(_fusion.source)} ${(_fusion.overallConfidence*100).round()}%',
            style:TextStyle(color:_sourceColor(_fusion.source,_theme),fontSize:9,fontWeight:FontWeight.w800)),
        ])),
        Positioned(right:120,top:58,child:GearIndicator(gear:displayGear,theme:_theme,enabled:true)),
        if(!compact || (gtEnabled&&gtSpec.showGForce))Positioned(left:18,bottom:14,child:Row(children:[_Metric('ACCEL','${_longitudinalAccel.toStringAsFixed(1)} m/s²'),const SizedBox(width:18),AccelerationBar(value:_longitudinalAccel,theme:_theme),const SizedBox(width:18),_Metric('G-FORCE','${(_totalAccel/9.80665).toStringAsFixed(2)} G'),const SizedBox(width:18),_Metric('MAX','${widget.settings.toDisplaySpeed(_maxSpeed).toStringAsFixed(0)} $unitLabel'),if(_session.active&&(!gtEnabled||gtSpec.showTrip))...[const SizedBox(width:18),_Metric('TRIP','${_session.distanceKm.toStringAsFixed(1)} km')]])),
        if(!compact)Positioned(right:18,bottom:14,child:Row(children:[_Metric('BRAKE MAX','${_maxBraking.toStringAsFixed(1)} m/s²')])),
        if (gtEnabled && gtSpec.showMap && navigationActive)
          Positioned(
            left: widget.settings.gtLayout == GtLayout.nav ? 92 : null,
            right: widget.settings.gtLayout == GtLayout.touring ? 18 : null,
            top: widget.settings.gtLayout == GtLayout.nav ? 46 : null,
            bottom: widget.settings.gtLayout == GtLayout.touring ? 78 : null,
            child: GtRouteMap(
              route: _navigationState!.route,
              position: _lastPosition,
              theme: _theme,
              nextManeuver: _navigationState!.nextManeuver,
              compact: gtLayout == GtLayout.touring,
              layout: gtLayout,
            ),
          ),
        if(!_ready)Center(child:Text('STARTING SENSORS...',style:TextStyle(color:_theme.secondary))),
      ])),
    ]);

    return Scaffold(
      backgroundColor:_theme.background,
      body:Stack(fit:StackFit.expand,children:[
        Transform(alignment:Alignment.center,transform:Matrix4.diagonal3Values(_mirror?-1:1,1,1),child:hudLayer),
        SafeArea(child:Stack(children:[
          if(!_session.active)Positioned(right:132,top:8,child:IconButton(onPressed:() async {
            await Navigator.of(context).push(MaterialPageRoute(builder:(_) => MapScreen(onRouteReady:(route) {
              if (!mounted) return;
              setState(() { _navigationRoute=route;_navigationState=null;_navigationMessage=null; });
              _navigationSession.start(route);
              _startDrive();
            })));
          },icon:Icon(Icons.map,color:_theme.accent),tooltip:'Map')),
          if(!_session.active)Positioned(right:86,top:8,child:IconButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DriveHistoryScreen(history:widget.history))),icon:Icon(Icons.history,color:_theme.accent),tooltip:'Driver History')),
          if(!_session.active)Positioned(right:40,top:8,child:IconButton(onPressed:_settings,icon:Icon(Icons.tune,color:_theme.accent),tooltip:'Settings')),
          if(_session.active)
            Positioned(
              right: 18,
              top: 10,
              child: FilledButton.icon(
                onPressed: _stopDrive,
                icon: const Icon(Icons.stop, size: 16),
                label: const Text('STOP'),
              ),
            ),
        ])),
      ]),
    );
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_gpsWatchdog?.cancel();_trafficTimer?.cancel();_gpsSub?.cancel();_motionSub?.cancel();_gpsService.dispose();_motionService.dispose();_obdSub?.cancel();_obdSession.dispose();_trafficService.dispose();_routeService.dispose();_navigationSession.stop();_session.dispose();WakelockPlus.disable();SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);SystemChrome.setPreferredOrientations(DeviceOrientation.values);super.dispose();}
}
String _sourceLabel(SensorSource source) => switch (source) {
  SensorSource.fused => 'FUSED',
  SensorSource.obd => 'OBD',
  SensorSource.gps => 'GPS',
  SensorSource.imu => 'IMU',
  SensorSource.unavailable => 'NO SENSOR',
};

IconData _sourceIcon(SensorSource source) => switch (source) {
  SensorSource.fused => Icons.merge_type,
  SensorSource.obd => Icons.bluetooth,
  SensorSource.gps => Icons.gps_fixed,
  SensorSource.imu => Icons.sensors,
  SensorSource.unavailable => Icons.sensors_off,
};

Color _sourceColor(SensorSource source, HudTheme theme) => switch (source) {
  SensorSource.fused => theme.accent,
  SensorSource.obd => theme.accent,
  SensorSource.gps => theme.secondary,
  SensorSource.imu => Colors.orangeAccent,
  SensorSource.unavailable => Colors.redAccent,
};

int _estimatedGear(double speedKmh){if(speedKmh<2)return 0;if(speedKmh<15)return 1;if(speedKmh<30)return 2;if(speedKmh<50)return 3;if(speedKmh<70)return 4;if(speedKmh<95)return 5;return 6;}

class _TrafficSignRail extends StatelessWidget {
  const _TrafficSignRail({required this.signs,required this.theme});final List<RelevantTrafficSign> signs;final HudTheme theme;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondary.withValues(alpha: .45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: signs
            .map(
              (sign) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: _TrafficSignItem(sign: sign, theme: theme),
              ),
            )
            .toList(),
      ),
    );
  }
}
class _TrafficSignItem extends StatelessWidget {
  const _TrafficSignItem({required this.sign,required this.theme});final RelevantTrafficSign sign;final HudTheme theme;
  @override Widget build(BuildContext context){final label=switch(sign.sign.type){TrafficSignType.stop=>'STOP',TrafficSignType.giveWay=>'GIVE',TrafficSignType.speedLimit=>sign.sign.value==null?'SPEED':'${sign.sign.value}',TrafficSignType.trafficSignals=>'LIGHT',TrafficSignType.roundabout=>'ROUND',TrafficSignType.crossing=>'CROSS',TrafficSignType.motorway=>'M-WAY',TrafficSignType.oneWay=>'1-WAY',TrafficSignType.unknown=>'ROAD',};final icon=switch(sign.sign.type){TrafficSignType.stop=>Icons.stop_circle,TrafficSignType.giveWay=>Icons.change_history,TrafficSignType.speedLimit=>Icons.speed,TrafficSignType.trafficSignals=>Icons.traffic,TrafficSignType.roundabout=>Icons.roundabout_left,TrafficSignType.crossing=>Icons.person,TrafficSignType.motorway=>Icons.directions_car,TrafficSignType.oneWay=>Icons.arrow_forward,TrafficSignType.unknown=>Icons.info_outline,};return Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,color:theme.accent,size:27),const SizedBox(height:2),Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:theme.accent,fontSize:8,fontWeight:FontWeight.w900)),Text('${sign.distanceMeters.round()}m',style:TextStyle(color:theme.secondary,fontSize:8,fontWeight:FontWeight.w700))]);}
}
class _Metric extends StatelessWidget {
  const _Metric(this.label,this.value);final String label,value;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10)),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700))]);
}
String _gaugeLabel(HudGaugeStyle style) => switch(style) { HudGaugeStyle.digital => 'DIGITAL CLASSIC', HudGaugeStyle.digitalGt => 'DIGITAL GT', HudGaugeStyle.circular => 'CIRCULAR', HudGaugeStyle.linear => 'LINEAR' };
