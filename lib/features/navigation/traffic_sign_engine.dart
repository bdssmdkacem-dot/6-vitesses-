import 'package:latlong2/latlong.dart';

enum TrafficSignType { stop, giveWay, speedLimit, trafficSignals, roundabout, crossing, motorway, oneWay, unknown }

class TrafficSign {
  const TrafficSign({required this.type, required this.position, this.value, this.name});
  final TrafficSignType type;
  final LatLng position;
  final int? value;
  final String? name;
}

class RelevantTrafficSign {
  const RelevantTrafficSign({required this.sign, required this.distanceMeters, required this.bearingDegrees});
  final TrafficSign sign;
  final double distanceMeters;
  final double bearingDegrees;
}

class TrafficSignEngine {
  TrafficSignEngine({this.maxDistanceMeters = 1000, this.aheadToleranceDegrees = 70});
  final double maxDistanceMeters;
  final double aheadToleranceDegrees;
  final Distance _distance = const Distance();

  List<RelevantTrafficSign> findRelevant({
    required LatLng vehiclePosition,
    required double headingDegrees,
    required Iterable<TrafficSign> signs,
  }) {
    final result = <RelevantTrafficSign>[];
    for (final sign in signs) {
      final distanceMeters = _distance.as(LengthUnit.Meter, vehiclePosition, sign.position);
      if (distanceMeters > maxDistanceMeters) continue;
      final bearing = _distance.bearing(vehiclePosition, sign.position);
      if (_angularDifference(headingDegrees, bearing) > aheadToleranceDegrees) continue;
      result.add(RelevantTrafficSign(sign: sign, distanceMeters: distanceMeters, bearingDegrees: bearing));
    }
    result.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return result;
  }

  double _angularDifference(double a, double b) {
    final delta = (a - b).abs() % 360;
    return delta > 180 ? 360 - delta : delta;
  }
}

TrafficSignType trafficSignTypeFromOsm(String value) {
  final normalized = value.toLowerCase().replaceAll('_', ':');
  if (normalized.contains('stop')) return TrafficSignType.stop;
  if (normalized.contains('give:way')) return TrafficSignType.giveWay;
  if (normalized.contains('maxspeed') || normalized.contains('speed')) return TrafficSignType.speedLimit;
  if (normalized.contains('traffic:signals') || normalized.contains('signals')) return TrafficSignType.trafficSignals;
  if (normalized.contains('roundabout')) return TrafficSignType.roundabout;
  if (normalized.contains('crossing')) return TrafficSignType.crossing;
  if (normalized.contains('motorway')) return TrafficSignType.motorway;
  if (normalized.contains('one:way') || normalized.contains('oneway')) return TrafficSignType.oneWay;
  return TrafficSignType.unknown;
}
