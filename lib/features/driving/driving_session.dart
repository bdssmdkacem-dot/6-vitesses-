import 'dart:async';
import 'package:flutter/foundation.dart';

class DrivingSession extends ChangeNotifier {
  bool _active=false; DateTime? _startedAt; Duration _elapsed=Duration.zero;
  double _distanceKm=0,_speedSum=0,_maxSpeed=0,_maxAcceleration=0,_maxBraking=0; int _samples=0; Timer? _timer;
  bool get active=>_active; Duration get elapsed=>_elapsed; double get distanceKm=>_distanceKm;
  double get averageSpeed=>_samples==0?0:_speedSum/_samples; double get maxSpeed=>_maxSpeed;
  double get maxAcceleration=>_maxAcceleration; double get maxBraking=>_maxBraking;
  void start(){_timer?.cancel();_active=true;_startedAt=DateTime.now();_elapsed=Duration.zero;_distanceKm=0;_speedSum=0;_samples=0;_maxSpeed=0;_maxAcceleration=0;_maxBraking=0;_timer=Timer.periodic(const Duration(seconds:1),(_){if(_startedAt!=null)_elapsed=DateTime.now().difference(_startedAt!);notifyListeners();});notifyListeners();}
  void addSample({required double speedKmh,required double acceleration}){if(!_active)return;_samples++;_speedSum+=speedKmh;_maxSpeed=speedKmh>_maxSpeed?speedKmh:_maxSpeed;_maxAcceleration=acceleration>_maxAcceleration?acceleration:_maxAcceleration;if(acceleration<_maxBraking)_maxBraking=acceleration;_distanceKm+=speedKmh/36000;notifyListeners();}
  void stop(){_active=false;_timer?.cancel();_timer=null;notifyListeners();}
  @override void dispose(){_timer?.cancel();super.dispose();}
}