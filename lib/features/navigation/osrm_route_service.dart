import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'navigation_models.dart';

class OsrmRoute {
  const OsrmRoute({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuvers,
    this.start,
    this.destination,
  });

  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<NavigationManeuver> maneuvers;
  final LatLng? start;
  final LatLng? destination;
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
        '${start.longitude},${start.latitude};'
        '${destination.longitude},${destination.latitude}';
    final uri = Uri.parse(
      '$baseUrl/route/v1/$profile/$coordinates'
      '?overview=full&geometries=geojson&steps=true',
    );

    http.Response? response;
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) break;
        if (response.statusCode < 500) {
          throw Exception('OSRM HTTP ${response.statusCode}');
        }
        lastError = Exception('OSRM HTTP ${response.statusCode}');
      } on TimeoutException catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    if (response == null || response.statusCode != 200) {
      throw lastError ?? Exception('OSRM request failed');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 'Ok') {
      throw Exception('OSRM: ${json['message'] ?? json['code']}');
    }

    final routes = json['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw Exception('OSRM returned no route');
    }

    final first = routes.first as Map<String, dynamic>;
    final maneuvers = <NavigationManeuver>[];
    final legs = (first['legs'] as List<dynamic>? ?? const []);
    for (final legValue in legs) {
      final leg = legValue as Map<String, dynamic>;
      for (final stepValue in (leg['steps'] as List<dynamic>? ?? const [])) {
        final step = stepValue as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        final location = maneuver?['location'] as List<dynamic>?;
        if (maneuver == null || location == null || location.length < 2) continue;
        maneuvers.add(NavigationManeuver(
          type: _maneuverType(
            maneuver['type']?.toString(),
            maneuver['modifier']?.toString(),
          ),
          position: LatLng(
            (location[1] as num).toDouble(),
            (location[0] as num).toDouble(),
          ),
          distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
          name: step['name']?.toString(),
          modifier: maneuver['modifier']?.toString(),
          exitNumber: (maneuver['exit'] as num?)?.toInt(),
          bearingBefore: (maneuver['bearing_before'] as num?)?.toDouble(),
          bearingAfter: (maneuver['bearing_after'] as num?)?.toDouble(),
          roadRef: step['ref']?.toString(),
        ));
      }
    }

    final geometry = first['geometry'] as Map<String, dynamic>?;
    final coordinatesList = geometry?['coordinates'] as List<dynamic>? ?? const [];
    final parsedGeometry = coordinatesList.map((point) {
      final pair = point as List<dynamic>;
      return LatLng(
        (pair[1] as num).toDouble(),
        (pair[0] as num).toDouble(),
      );
    }).toList(growable: false);

    if (parsedGeometry.length < 2) {
      throw Exception('OSRM returned an invalid route geometry');
    }

    return OsrmRoute(
      geometry: parsedGeometry,
      distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (first['duration'] as num?)?.toDouble() ?? 0,
      maneuvers: maneuvers,
      start: start,
      destination: destination,
    );
  }

  NavigationManeuverType _maneuverType(String? type, String? modifier) {
    switch (type) {
      case 'depart': return NavigationManeuverType.depart;
      case 'arrive': return NavigationManeuverType.arrive;
      case 'roundabout': return NavigationManeuverType.roundabout;
      case 'merge': return NavigationManeuverType.merge;
      case 'fork': return NavigationManeuverType.fork;
      case 'on_ramp': return NavigationManeuverType.onRamp;
      case 'off_ramp': return NavigationManeuverType.offRamp;
      case 'end of road': return NavigationManeuverType.endOfRoad;
      case 'new name': return NavigationManeuverType.straight;
      case 'continue': return _turnFromModifier(modifier);
      default: return _turnFromModifier(modifier);
    }
  }

  NavigationManeuverType _turnFromModifier(String? modifier) {
    switch (modifier) {
      case 'left': return NavigationManeuverType.turnLeft;
      case 'right': return NavigationManeuverType.turnRight;
      case 'sharp left': return NavigationManeuverType.sharpLeft;
      case 'sharp right': return NavigationManeuverType.sharpRight;
      case 'uturn': return NavigationManeuverType.uTurn;
      case 'straight': return NavigationManeuverType.straight;
      default: return NavigationManeuverType.unknown;
    }
  }

  void dispose() => _client.close();
}
