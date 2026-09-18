import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'traffic_sign_engine.dart';

class OsmTrafficService {
  OsmTrafficService({
    this.endpoint = 'https://overpass-api.de/api/interpreter',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final http.Client _client;

  Future<List<TrafficSign>> nearby({
    required LatLng center,
    double radiusMeters = 1000,
  }) async {
    final lat = center.latitude.toStringAsFixed(6);
    final lon = center.longitude.toStringAsFixed(6);
    final radius = radiusMeters.round();
    final query = '''
[out:json][timeout:12];
(
  node(around:$radius,$lat,$lon)["highway"="stop"];
  node(around:$radius,$lat,$lon)["highway"="give_way"];
  node(around:$radius,$lat,$lon)["highway"="traffic_signals"];
  node(around:$radius,$lat,$lon)["highway"="crossing"];
  node(around:$radius,$lat,$lon)["traffic_sign"];
  way(around:$radius,$lat,$lon)["maxspeed"];
  way(around:$radius,$lat,$lon)["highway"="motorway"];
  way(around:$radius,$lat,$lon)["oneway"];
);
out center tags;
''';
    final response = await _client.post(
      Uri.parse(endpoint),
      headers: const {'Accept': 'application/json'},
      body: {'data': query},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Overpass HTTP ${response.statusCode}');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = root['elements'] as List<dynamic>? ?? const [];
    final result = <TrafficSign>[];
    for (final value in elements) {
      final element = value as Map<String, dynamic>;
      final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
      final rawType = [
        tags['highway'],
        tags['traffic_sign'],
        tags['maxspeed'],
        tags['oneway'],
      ].whereType<String>().join(' ');
      final type = trafficSignTypeFromOsm(rawType);
      if (type == TrafficSignType.unknown) continue;

      final location = _location(element);
      if (location == null) continue;
      final maxSpeed = _speed(tags['maxspeed']?.toString());
      result.add(TrafficSign(
        type: type,
        position: location,
        value: maxSpeed,
        name: tags['name']?.toString(),
      ));
    }
    return result;
  }

  LatLng? _location(Map<String, dynamic> element) {
    final lat = element['lat'];
    final lon = element['lon'];
    if (lat is num && lon is num) return LatLng(lat.toDouble(), lon.toDouble());
    final center = element['center'] as Map<String, dynamic>?;
    final clat = center?['lat'];
    final clon = center?['lon'];
    if (clat is num && clon is num) return LatLng(clat.toDouble(), clon.toDouble());
    return null;
  }

  int? _speed(String? value) {
    if (value == null) return null;
    final match = RegExp(r'(\\d+(?:[.,]\\d+)?)').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'))?.round();
  }

  void dispose() => _client.close();
}
