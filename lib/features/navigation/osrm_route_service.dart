import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmRoute {
  const OsrmRoute({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
}

class OsrmRouteService {
  OsrmRouteService({
    this.baseUrl = 'https://router.project-osrm.org',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<OsrmRoute> route({
    required LatLng start,
    required LatLng destination,
    String profile = 'driving',
  }) async {
    final coordinates =
        '\${start.longitude},\${start.latitude};'
        '\${destination.longitude},\${destination.latitude}';
    final uri = Uri.parse(
      '\$baseUrl/route/v1/\$profile/\$coordinates'
      '?overview=full&geometries=geojson&steps=true',
    );
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('OSRM HTTP \${response.statusCode}');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 'Ok') throw Exception('OSRM: \${json['message'] ?? json['code']}');
    final routes = json['routes'] as List<dynamic>;
    if (routes.isEmpty) throw Exception('OSRM returned no route');
    final first = routes.first as Map<String, dynamic>;
    final geometry = first['geometry'] as Map<String, dynamic>;
    final coordinatesList = geometry['coordinates'] as List<dynamic>;
    return OsrmRoute(
      geometry: coordinatesList.map((point) {
        final pair = point as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList(growable: false),
      distanceMeters: (first['distance'] as num).toDouble(),
      durationSeconds: (first['duration'] as num).toDouble(),
    );
  }

  void dispose() => _client.close();
}
