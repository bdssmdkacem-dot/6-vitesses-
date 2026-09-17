import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'models/hud_theme.dart';
import 'widgets/speed_gauge.dart';
import '../driving/driving_session.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});
  @override State<HudScreen> createState()=>_HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  final _session=DrivingSession();
  double _speed=0,_accel=0,_maxSpeed=0,_maxAccel=0;
  bool _mirror=false,_running=false;
  String _gps='GPS';
  HudTheme _theme=HudTheme.midnight;
  HudGaugeStyle _style=HudGaugeStyle.digital;

  @override void initState(){super.initState();_enterHud();_startSensors();}
  Future<void> _enterHud()async{
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await WakelockPlus.enable();
  }
  Future<void> _startSensors()async{
    if(!await Geolocator.isLocationServiceEnabled()){if(mounted)setState(()=>_gps='GPS OFF');}
    else{
      var p=await Geolocator.checkPermission();
      if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied||p==LocationPermission.deniedForever){if(mounted)setState(()=>_gps='GPS PERMISSION');}
      else{
        _positionSub=Geolocator.getPositionStream(locationSettings:const LocationSettings(accuracy:LocationAccuracy.best,distanceFilter:0)).listen((p){
          final s=(p.speed*3.6).clamp(0,400).toDouble();
          if(!mounted)return;
          setState(()=>_speed=s);
          if(s>_maxSpeed&&mounted)setState(()=>_maxSpeed=s);
          if(_session.active)_session.addSample(speedKmh:s,acceleration:_accel);
          if(mounted)setState(()=>_gps=p.accuracy<=25?'GPS':'GPS ±${p.accuracy.round()}m');
        });
      }
    }
    _accelSub=userAccelerometerEventStream(samplingPeriod:const Duration(milliseconds:100)).listen((e){
      final a=_sqrt(e.x*e.x+e.y*e.y+e.z*e.z);
      if(!mounted)return;
      setState(()=>_accel=a);
      if(a>_maxAccel&&mounted)setState(()=>_maxAccel=a);
    });
    if(mounted)setState(()=>_running=true);
  }

  void _settings(){
    showModalBottomSheet(context:context,backgroundColor:_theme.background,builder:(_)=>StatefulBuilder(
      builder:(context,setSheet)=>Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('HUD SETTINGS',style:TextStyle(color:_theme.accent,fontSize:18,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        Wrap(spacing:8,children:HudTheme.all.map((t)=>ChoiceChip(label:Text(t.name),selected:_theme==t,onSelected:(_){setState(()=>_theme=t);setSheet((){});})).toList()),
        const SizedBox(height:12),
        Wrap(spacing:8,children:HudGaugeStyle.values.map((s)=>ChoiceChip(label:Text(s.name.toUpperCase()),selected:_style==s,onSelected:(_){setState(()=>_style=s);setSheet((){});})).toList()),
        SwitchListTile(title:const Text('Mirror HUD'),value:_mirror,onChanged:(v)=>setState(()=>_mirror=v)),
        FilledButton.icon(onPressed:(){_session.active?_session.stop():_session.start();setSheet((){});setState((){});},icon:Icon(_session.active?Icons.stop:Icons.play_arrow),label:Text(_session.active?'END DRIVE':'START DRIVE')),
      ]))));
  }

  @override Widget build(BuildContext context){
    final body=Scaffold(backgroundColor:_theme.background,body:SafeArea(child:Stack(children:[
      Center(child:SpeedGauge(speed:_speed,maxSpeed:240,style:_style,theme:_theme)),
      Positioned(left:18,top:14,child:Text(_gps,style:TextStyle(color:_theme.secondary,fontSize:12))),
      Positioned(right:10,top:6,child:IconButton(onPressed:_settings,icon:Icon(Icons.tune,color:_theme.accent))),
      Positioned(left:18,bottom:14,child:Row(children:[
        _Metric('ACCEL','${_accel.toStringAsFixed(1)} m/s²'),
        const SizedBox(width:24),_Metric('MAX','${_maxSpeed.toStringAsFixed(0)} km/h'),
        if(_session.active)...[const SizedBox(width:24),_Metric('TRIP','${_session.distanceKm.toStringAsFixed(1)} km')],
      ])),
      if(!_running)Center(child:Text('WAITING FOR SENSORS',style:TextStyle(color:_theme.secondary))),
    ])));
    return Transform(alignment:Alignment.center,transform:Matrix4.diagonal3Values(_mirror?-1:1,1,1),child:body);
  }

  @override void dispose(){_positionSub?.cancel();_accelSub?.cancel();_session.dispose();WakelockPlus.disable();SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);SystemChrome.setPreferredOrientations(DeviceOrientation.values);super.dispose();}
}
class _Metric extends StatelessWidget{
  const _Metric(this.label,this.value);final String label,value;
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10)),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w700))]);
}
double _sqrt(double v){if(v<=0)return 0;var g=v/2;for(var i=0;i<16;i++)g=(g+v/g)/2;return g;}
