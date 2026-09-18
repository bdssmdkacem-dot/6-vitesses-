import 'dart:convert';

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
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<PlaceSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: {
        'q': trimmed,
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
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Search HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid geocoding response');
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

  void dispose() => _client.close();
}
