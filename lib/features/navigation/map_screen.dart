import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'nominatim_search_service.dart';
import 'osrm_route_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.onRouteReady});
  final ValueChanged<OsrmRoute>? onRouteReady;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final OsrmRouteService _routeService = OsrmRouteService();
  final NominatimSearchService _searchService = NominatimSearchService();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<Position>? _positionSub;
  LatLng? _position;
  LatLng? _destination;
  PlaceSearchResult? _selectedPlace;
  OsrmRoute? _route;
  List<PlaceSearchResult> _results = const [];
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  Future<void> _startLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _error = 'Location permission is required.');
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      );
      _onPosition(current);

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(_onPosition);
    } catch (error) {
      if (mounted) setState(() => _error = 'GPS unavailable: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    final next = LatLng(position.latitude, position.longitude);
    setState(() => _position = next);
    if (_route == null) {
      _mapController.move(next, _mapController.camera.zoom);
    }
  }

  Future<void> _searchPlaces() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });

    try {
      final results = await _searchService.search(query);
      if (!mounted) return;
      setState(() => _results = results);
      if (results.isEmpty) {
        setState(() => _error = 'No places found.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Search unavailable: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectPlace(PlaceSearchResult place) async {
    setState(() {
      _selectedPlace = place;
      _destination = place.position;
      _results = const [];
      _route = null;
      _error = null;
    });
    _mapController.move(place.position, 15);
    await _routeTo(place.position);
  }

  Future<void> _routeTo(LatLng destination) async {
    final start = _position;
    if (start == null) {
      setState(() => _error = 'Waiting for current GPS position.');
      return;
    }

    setState(() {
      _destination = destination;
      _route = null;
      _error = null;
      _loading = true;
    });

    try {
      final route = await _routeService.route(
        start: start,
        destination: destination,
      );
      if (!mounted) return;
      setState(() => _route = route);
    } catch (error) {
      if (mounted) setState(() => _error = 'Route unavailable: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startNavigation() {
    final route = _route;
    if (route == null) return;
    widget.onRouteReady?.call(route);
    if (mounted) Navigator.of(context).pop();
  }

  void _centerOnPosition() {
    final position = _position;
    if (position != null) _mapController.move(position, 16);
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;

    return Scaffold(
      appBar: AppBar(
        title: const Text('6 Vitesses • Navigation'),
        actions: [
          IconButton(
            onPressed: _centerOnPosition,
            icon: const Icon(Icons.my_location),
            tooltip: 'My location',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: position ?? const LatLng(34.0209, -6.8416),
              initialZoom: position == null ? 6 : 16,
              onLongPress: (_, point) => _routeTo(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                fallbackUrl:
                    'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.sixvitesses',
              ),
              if (_route != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route!.geometry,
                      strokeWidth: 6,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (position != null)
                    Marker(
                      point: position,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.navigation, size: 36, color: Colors.blue),
                    ),
                  if (_destination != null)
                    Marker(
                      point: _destination!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on, size: 38, color: Colors.red),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                  TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _searchPlaces(),
                            decoration: const InputDecoration(
                              hintText: 'Search city, street or place worldwide',
                              prefixIcon: Icon(Icons.search),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _searching ? null : _searchPlaces,
                          icon: _searching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.arrow_forward),
                        ),
                      ],
                    ),
                    if (_results.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(
                                result.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectPlace(result),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_route != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedPlace?.displayName ?? 'Selected destination',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_route!.distanceMeters / 1000).toStringAsFixed(1)} km • '
                              '${(_route!.durationSeconds / 60).round()} min',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _startNavigation,
                        icon: const Icon(Icons.navigation),
                        label: const Text('START'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_loading)
            const Positioned(
              top: 86,
              left: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Loading…'),
                    ],
                  ),
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: _route == null ? 16 : 88,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _searchController.dispose();
    _searchService.dispose();
    _routeService.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
