import 'dart:async';
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
  List<TrafficSign>? _cache;
  DateTime? _cacheAt;
  String? _cacheKey;

  Future<List<TrafficSign>> nearby({
    required LatLng center,
    double radiusMeters = 1000,
  }) async {
    final key = '${center.latitude.toStringAsFixed(3)}:${center.longitude.toStringAsFixed(3)}:$radiusMeters';
    final now = DateTime.now();
    if (_cache != null && _cacheAt != null && _cacheKey == key &&
        now.difference(_cacheAt!) < const Duration(seconds: 30)) return _cache!;
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
    http.Response? response;
    Object? lastError;
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          response = await _client.post(Uri.parse(endpoint), headers: const {'Accept': 'application/json'}, body: {'data': query}).timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) break;
          if (response.statusCode < 500) throw Exception('Overpass HTTP ${response.statusCode}');
          lastError = Exception('Overpass HTTP ${response.statusCode}');
        } on TimeoutException catch (error) {
          lastError = error;
        }
        if (attempt < 2) await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
      if (response == null || response.statusCode != 200) throw lastError ?? Exception('Overpass request failed');

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
        tags['junction'],
      ].whereType<String>().join(' ');
      var type = trafficSignTypeFromOsm(rawType);
      if (type == TrafficSignType.unknown && tags['junction']?.toString() == 'roundabout') type = TrafficSignType.roundabout;
      if (type == TrafficSignType.unknown) continue;

      final location = _location(element);
      if (location == null) continue;
      final maxSpeed = _speed(tags['maxspeed']?.toString());
      result.add(TrafficSign(
        type: type,
        position: location,
        value: maxSpeed,
        name: tags['name']?.toString(),
        directionDegrees: _direction(tags['direction']?.toString()),
      ));
    }
    _cache = List<TrafficSign>.unmodifiable(result);
    _cacheAt = now;
    _cacheKey = key;
    return _cache!;
    } catch (_) {
      if (_cache != null && _cacheAt != null && now.difference(_cacheAt!) < const Duration(minutes: 2)) return _cache!;
      rethrow;
    }
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
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'))?.round();
  }

  double? _direction(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    final numeric = double.tryParse(normalized);
    if (numeric != null) return numeric % 360;
    const compass = <String, double>{'n': 0, 'ne': 45, 'e': 90, 'se': 135, 's': 180, 'sw': 225, 'w': 270, 'nw': 315};
    return compass[normalized];
  }

  void dispose() => _client.close();
}
