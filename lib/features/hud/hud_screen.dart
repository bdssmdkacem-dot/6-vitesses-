import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../driving/drive_history.dart';
import '../driving/drive_history_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../driving/driving_session.dart';
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
  StreamSubscription<GpsSample>? _gpsSub; StreamSubscription<MotionSample>? _motionSub; Timer? _gpsWatchdog;
  double _speed=0,_longitudinalAccel=0,_totalAccel=0,_maxSpeed=0,_maxAccel=0,_maxBraking=0,_gpsAccuracy=double.infinity; double? _rpm;
  bool _restartingGps=false;
  int _gear=0; bool _mirror=false,_ready=false,_gpsStale=true; HudTheme _theme=HudTheme.midnight; HudGaugeStyle _style=HudGaugeStyle.digital;

  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_enterHud();_startSensors();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed){_enterHud();_restartGps();}
    if(state==AppLifecycleState.paused && !_session.active){_gpsService.stop();}
  }
  Future<void> _restartGps() async {
    if(_restartingGps || !mounted) return;
    _restartingGps=true;
    try { await _gpsService.start(); } finally { _restartingGps=false; }
  }
  Future<void> _enterHud()async{await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);await WakelockPlus.enable();}
  Future<void> _startSensors()async{
    _gpsSub=_gpsService.samples.listen((sample){if(!mounted)return;setState((){_speed=sample.speedKmh;_longitudinalAccel=sample.longitudinalAcceleration;_gpsStale=sample.isStale;_gpsAccuracy=sample.accuracyM;if(_speed>_maxSpeed)_maxSpeed=_speed;if(_longitudinalAccel>_maxAccel)_maxAccel=_longitudinalAccel;if(_longitudinalAccel<_maxBraking)_maxBraking=_longitudinalAccel;});if(_session.active&&!sample.isStale)_session.addSample(speedKmh:sample.speedKmh,acceleration:sample.longitudinalAcceleration,timestamp:sample.timestamp);});
    _motionSub=_motionService.samples.listen((sample){
      if(!mounted)return;
      setState((){
        // Use the high-rate IMU signal for the live acceleration display.
        // GPS remains the authoritative speed/session source.
        _longitudinalAccel=sample.longitudinalAcceleration;
        _totalAccel=sample.totalAcceleration;
        if(_longitudinalAccel>_maxAccel)_maxAccel=_longitudinalAccel;
        if(_longitudinalAccel<_maxBraking)_maxBraking=_longitudinalAccel;
      });
    });
    _motionService.start();await _gpsService.start();_gpsWatchdog?.cancel();_gpsWatchdog=Timer.periodic(const Duration(seconds:2),(_){
      if(!mounted)return;
      final stale=_gpsService.isStale;
      if(stale!=_gpsStale)setState((){_gpsStale=stale;if(stale){_speed=0;_longitudinalAccel=0;_gpsAccuracy=double.infinity;}});
      if(stale && !_session.active) _restartGps();
    });if(mounted)setState(()=>_ready=true);
  }
  void _startDrive(){_session.start();setState((){_maxSpeed=0;_maxAccel=0;_maxBraking=0;});}
  Future<void> _stopDrive()async{final record=_session.stop();await widget.history.add(record);if(mounted)setState((){});}
  Future<void> _applyPreset(HudPreset preset) async {
    switch (preset) {
      case HudPreset.sport:
        await widget.settings.setTheme(HudTheme.redline);
        await widget.settings.setGauge(HudGaugeStyle.circular);
        await widget.settings.setCompact(false);
        await widget.settings.setShowRpm(true);
        await widget.settings.setAnimations(true);
        break;
      case HudPreset.daily:
        await widget.settings.setTheme(HudTheme.midnight);
        await widget.settings.setGauge(HudGaugeStyle.digital);
        await widget.settings.setCompact(false);
        await widget.settings.setShowRpm(true);
        await widget.settings.setAnimations(true);
        break;
      case HudPreset.night:
        await widget.settings.setTheme(HudTheme.ice);
        await widget.settings.setGauge(HudGaugeStyle.digital);
        await widget.settings.setCompact(true);
        await widget.settings.setShowRpm(false);
        await widget.settings.setAnimations(false);
        break;
      case HudPreset.windshield:
        await widget.settings.setTheme(HudTheme.midnight);
        await widget.settings.setGauge(HudGaugeStyle.digital);
        await widget.settings.setCompact(true);
        await widget.settings.setShowRpm(false);
        await widget.settings.setAnimations(true);
        await widget.settings.setMirror(true);
        break;
      case HudPreset.performance:
        await widget.settings.setTheme(HudTheme.neon);
        await widget.settings.setGauge(HudGaugeStyle.linear);
        await widget.settings.setCompact(false);
        await widget.settings.setShowRpm(true);
        await widget.settings.setAnimations(true);
        break;
    }
    await widget.settings.setPreset(preset);
    if (mounted) setState(() {});
  }
  void _settings(){
    if(_session.active)return;
    showModalBottomSheet(context:context,backgroundColor:_theme.background,isScrollControlled:true,builder:(_)=>StatefulBuilder(builder:(context,setSheet)=>SingleChildScrollView(
      padding:const EdgeInsets.fromLTRB(20,20,20,28),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('HUD SETTINGS',style:TextStyle(color:_theme.accent,fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:12),\n        Text('DASHBOARD PRESETS',style:TextStyle(color:_theme.secondary,fontSize:11,fontWeight:FontWeight.w700)),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:8,children:HudPreset.values.map((preset)=>ChoiceChip(label:Text(preset.name.toUpperCase()),selected:widget.settings.preset==preset,onSelected:(_)=>_applyPreset(preset)).toList()),
        const SizedBox(height:12),
        Wrap(spacing:8,runSpacing:8,children:HudTheme.all.map((theme)=>ChoiceChip(label:Text(theme.name),selected:_theme==theme,onSelected:(_)async{await widget.settings.setTheme(theme);await widget.settings.setGauge(theme.defaultGauge);setState((){_theme=theme;_style=theme.defaultGauge;});setSheet((){});})).toList()),
        const SizedBox(height:12),
        Wrap(spacing:8,children:HudGaugeStyle.values.map((style)=>ChoiceChip(label:Text(style.name.toUpperCase()),selected:_style==style,onSelected:(_)async{await widget.settings.setGauge(style);setState(()=>_style=style);setSheet((){});})).toList()),
        const SizedBox(height:8),
        GearIndicator(gear:_gear,theme:_theme),
        Wrap(spacing:6,children:List.generate(7,(index)=>ChoiceChip(label:Text(index==0?'N':'$index'),selected:_gear==index,onSelected:(_)async{await widget.settings.setGear(index);setState(()=>_gear=index);setSheet((){});})).toList()),
        ListTile(title:Text(widget.settings.vehicleName),subtitle:Text(widget.settings.vehicleModel.isEmpty?'Vehicle profile':widget.settings.vehicleModel),leading:const Icon(Icons.directions_car),onTap:()async{
          final name=TextEditingController(text:widget.settings.vehicleName),model=TextEditingController(text:widget.settings.vehicleModel);
          await showDialog<void>(context:context,builder:(_)=>AlertDialog(title:const Text('Vehicle profile'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),TextField(controller:model,decoration:const InputDecoration(labelText:'Model'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()async{await widget.settings.setVehicle(name:name.text,model:model.text);if(context.mounted)Navigator.pop(context);setSheet((){});},child:const Text('Save'))]));
        }),
        DropdownButtonFormField<SpeedUnit>(initialValue:widget.settings.unit,decoration:const InputDecoration(labelText:'Speed unit'),items:const[DropdownMenuItem(value:SpeedUnit.kmh,child:Text('km/h')),DropdownMenuItem(value:SpeedUnit.mph,child:Text('mph'))],onChanged:(value)async{if(value!=null)await widget.settings.setUnit(value);setSheet((){});}),
        const SizedBox(height:8),
        ListTile(title:Text('Gauge limit: ${widget.settings.speedLimit.toStringAsFixed(0)}'),subtitle:Slider(min:60,max:360,divisions:30,value:widget.settings.speedLimit,onChanged:(value)async{await widget.settings.setSpeedLimit(value);setSheet((){});})),
        SwitchListTile(title:const Text('Animations'),subtitle:const Text('Smooth speed, gauge and background motion'),value:widget.settings.animations,onChanged:(value)async{await widget.settings.setAnimations(value);setSheet((){});}),
        SwitchListTile(title:const Text('RPM indicator'),subtitle:Text(widget.settings.obdEnabled?'Waiting for OBD-II telemetry':'Ready for OBD-II'),value:widget.settings.showRpm,onChanged:(value)async{await widget.settings.setShowRpm(value);setSheet((){});}),
        SwitchListTile(title:const Text('Compact HUD'),subtitle:const Text('Reduce secondary information while driving'),value:widget.settings.compact,onChanged:(value)async{await widget.settings.setCompact(value);setSheet((){});}),
        SwitchListTile(title:const Text('OBD-II ready'),subtitle:const Text('GPS remains the fallback source until a Bluetooth adapter is connected.'),value:widget.settings.obdEnabled,onChanged:(value)async{await widget.settings.setObdEnabled(value);setSheet((){});}),
        SwitchListTile(title:const Text('Mirror HUD'),value:_mirror,onChanged:(value)async{await widget.settings.setMirror(value);setState(()=>_mirror=value);setSheet((){});}),
        const SizedBox(height:8),
        FilledButton.icon(onPressed:(){_startDrive();Navigator.pop(context);},icon:const Icon(Icons.play_arrow),label:const Text('START DRIVE')),
      ]))));
  }

  @override Widget build(BuildContext context){
    _theme=widget.settings.theme;_style=widget.settings.gauge;_mirror=widget.settings.mirror;_gear=widget.settings.gear;
    final unitLabel=widget.settings.unit==SpeedUnit.kmh?'km/h':'mph',showRpm=widget.settings.showRpm&&_theme.showRpm,compact=widget.settings.compact;
    final hudContent=Stack(fit:StackFit.expand,children:[
      HudBackground(theme:_theme,animate:widget.settings.animations),
      SafeArea(child:Stack(children:[
        Center(child:SpeedGauge(speed:widget.settings.toDisplaySpeed(_speed),maxSpeed:widget.settings.toDisplaySpeed(widget.settings.speedLimit),style:_style,theme:_theme,unitLabel:unitLabel,animate:widget.settings.animations)),
        if(showRpm)Positioned(top:compact?8:42,left:0,right:0,child:Center(child:RpmIndicator(rpm:_rpm,theme:_theme,style:_theme.rpmStyle,animate:widget.settings.animations))),
        Positioned(left:0,right:0,top:10,child:Center(child:Text(widget.settings.vehicleName.toUpperCase(),style:TextStyle(color:_theme.secondary,fontSize:10,fontWeight:FontWeight.w700,letterSpacing:2)))),
        Positioned(left:18,top:14,child:Row(children:[Icon(_gpsStale?Icons.gps_off:Icons.gps_fixed,size:15,color:_gpsStale?Colors.redAccent:_theme.secondary),const SizedBox(width:6),Text(_gpsStale?'GPS LOST':'GPS ±${_gpsAccuracy.isFinite?_gpsAccuracy.toStringAsFixed(0):'--'}m',style:TextStyle(color:_gpsStale?Colors.redAccent:_theme.secondary,fontSize:12,fontWeight:FontWeight.w700))])),
        Positioned(right:18,top:12,child:GearIndicator(gear:_gear,theme:_theme,enabled:!_session.active)),\n        Positioned(right:86,top:14,child:_SpeedLimitBadge(speed:_speed,limit:widget.settings.toDisplaySpeed(widget.settings.speedLimit),theme:_theme)),
        if(!_session.active)Positioned(right:86,top:8,child:IconButton(onPressed:_settings,icon:Icon(Icons.tune,color:_theme.accent),tooltip:'Settings')),
        if(!_session.active)Positioned(left:0,right:0,bottom:10,child:Center(child:FilledButton.icon(onPressed:_startDrive,icon:const Icon(Icons.play_arrow),label:const Text('START DRIVE')))),
        if(_session.active)Positioned(right:18,top:10,child:FilledButton.icon(onPressed:_stopDrive,icon:const Icon(Icons.stop,size:16),label:const Text('STOP'))),
        if(!compact)Positioned(left:18,bottom:14,child:Row(children:[
          _Metric('ACCEL','${_longitudinalAccel.toStringAsFixed(1)} m/s²'),const SizedBox(width:18),AccelerationBar(value:_longitudinalAccel,theme:_theme),const SizedBox(width:18),_Metric('G-FORCE','${(_totalAccel/9.80665).toStringAsFixed(2)} G'),const SizedBox(width:18),_Metric('MAX','${widget.settings.toDisplaySpeed(_maxSpeed).toStringAsFixed(0)} $unitLabel'),
          if(_session.active)...[const SizedBox(width:18),_Metric('TRIP','${_session.distanceKm.toStringAsFixed(1)} km')],
        ])),
        if(!compact)Positioned(right:18,bottom:14,child:Row(children:[if(!_session.active)IconButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>DriveHistoryScreen(history:widget.history))),icon:Icon(Icons.history,color:_theme.accent),tooltip:'History'),_Metric('BRAKE MAX','${_maxBraking.toStringAsFixed(1)} m/s²')])),
        if(!_ready)Center(child:Text('STARTING SENSORS...',style:TextStyle(color:_theme.secondary))),
      ])),
    ]);

    // Windshield mode is a strict horizontal mirror only. The HUD is mirrored,
    // while the settings/navigation layer remains normal and readable.
    final mirroredHud=Transform(
      alignment:Alignment.center,
      transform:Matrix4.identity()..scaleByDouble(_mirror ? -1.0 : 1.0, 1.0, 1.0, 1.0),
      child:hudContent,
    );

    return Scaffold(
      backgroundColor:_theme.background,
      body:mirroredHud,
    );
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_gpsWatchdog?.cancel();_gpsSub?.cancel();_motionSub?.cancel();_gpsService.stop();_gpsService.dispose();_motionService.dispose();_session.dispose();WakelockPlus.disable();SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);SystemChrome.setPreferredOrientations(DeviceOrientation.values);super.dispose();}
}
class _Metric extends StatelessWidget {
  const _Metric(this.label,this.value); final String label,value;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10)),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700))]);
}

class _SpeedLimitBadge extends StatelessWidget {
  const _SpeedLimitBadge({required this.speed,required this.limit,required this.theme});
  final double speed,limit; final HudTheme theme;
  @override Widget build(BuildContext context){
    final over=speed>limit&&speed>3;
    return Container(width:44,height:44,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:over?Colors.redAccent:theme.secondary.withValues(alpha:.55),width:2),color:theme.background.withValues(alpha:.72)),child:Center(child:Text(limit.toStringAsFixed(0),style:TextStyle(color:over?Colors.redAccent:theme.secondary,fontSize:12,fontWeight:FontWeight.w800))));
  }
}
