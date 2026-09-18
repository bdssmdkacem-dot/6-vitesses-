import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.displayName,
    required this.position,
    this.type,
    this.category,
  });

  final String displayName;
  final LatLng position;
  final String? type;
  final String? category;
}

class NominatimSearchService {
  NominatimSearchService({
    this.baseUrl = 'https://nominatim.openstreetmap.org',
    this.photonBaseUrl = 'https://photon.komoot.io',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String photonBaseUrl;
  final http.Client _client;

  Future<List<PlaceSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    Object? primaryError;
    try {
      return await _searchNominatim(trimmed);
    } catch (error) {
      primaryError = error;
    }

    try {
      return await _searchPhoton(trimmed);
    } catch (fallbackError) {
      throw SearchServiceException(
        'Geocoding services unavailable. '
        'Primary: ${_describeNetworkError(primaryError)}. '
        'Fallback: ${_describeNetworkError(fallbackError)}.',
      );
    }
  }

  Future<List<PlaceSearchResult>> _searchNominatim(String query) async {
    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': '8',
        'addressdetails': '1',
        'dedupe': '1',
      },
    );

    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'en,fr,ar',
        'User-Agent': '6-Vitesses/0.2.1 (Android driving navigation app)',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw SearchServiceException('Nominatim HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const SearchServiceException('Invalid Nominatim response.');
    }

    return decoded.whereType<Map<String, dynamic>>().map((item) {
      return PlaceSearchResult(
        displayName: item['display_name']?.toString() ?? 'Unknown place',
        position: LatLng(
          double.parse(item['lat'].toString()),
          double.parse(item['lon'].toString()),
        ),
        type: item['type']?.toString(),
        category: item['category']?.toString(),
      );
    }).toList(growable: false);
  }

  Future<List<PlaceSearchResult>> _searchPhoton(String query) async {
    final uri = Uri.parse('$photonBaseUrl/api').replace(
      queryParameters: {
        'q': query,
        'limit': '8',
        'lang': 'en',
      },
    );

    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Accept-Language': 'en,fr,ar',
        'User-Agent': '6-Vitesses/0.2.1 (Android driving navigation app)',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw SearchServiceException('Photon HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const SearchServiceException('Invalid Photon response.');
    }

    final features = decoded['features'];
    if (features is! List) {
      throw const SearchServiceException('Invalid Photon feature list.');
    }

    return features.whereType<Map<String, dynamic>>().map((feature) {
      final geometry = feature['geometry'];
      final properties = feature['properties'];
      if (geometry is! Map<String, dynamic> ||
          properties is! Map<String, dynamic>) {
        throw const SearchServiceException('Invalid Photon place.');
      }

      final coordinates = geometry['coordinates'];
      if (coordinates is! List || coordinates.length < 2) {
        throw const SearchServiceException('Invalid Photon coordinates.');
      }

      final lon = double.parse(coordinates[0].toString());
      final lat = double.parse(coordinates[1].toString());

      final parts = <String>[
        properties['name']?.toString() ?? '',
        properties['street']?.toString() ?? '',
        properties['city']?.toString() ??
            properties['district']?.toString() ??
            '',
        properties['state']?.toString() ?? '',
        properties['country']?.toString() ?? '',
      ].where((part) => part.trim().isNotEmpty).toList();

      return PlaceSearchResult(
        displayName: parts.join(', '),
        position: LatLng(lat, lon),
        type: properties['osm_value']?.toString(),
        category: properties['osm_key']?.toString(),
      );
    }).toList(growable: false);
  }

  String _describeNetworkError(Object? error) {
    if (error is SocketException) {
      return 'DNS/network failure (${error.message})';
    }
    if (error is TimeoutException) {
      return 'timeout';
    }
    return error?.toString() ?? 'unknown error';
  }

  void dispose() => _client.close();
}

class SearchServiceException implements Exception {
  const SearchServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
