import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'osrm_route_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final OsrmRouteService _routeService = OsrmRouteService();
  StreamSubscription<Position>? _positionSub;
  LatLng? _position;
  LatLng? _destination;
  OsrmRoute? _route;
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _startLocation(); }

  Future<void> _startLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _error = 'Location permission is required.');
        return;
      }
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
      );
      _onPosition(current);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
      ).listen(_onPosition);
    } catch (error) {
      if (mounted) setState(() => _error = 'GPS: \$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    final next = LatLng(position.latitude, position.longitude);
    setState(() => _position = next);
    _mapController.move(next, _mapController.camera.zoom);
  }

  Future<void> _routeTo(LatLng destination) async {
    final start = _position;
    if (start == null) return;
    setState(() { _destination = destination; _route = null; _error = null; _loading = true; });
    try {
      final route = await _routeService.route(start: start, destination: destination);
      if (mounted) setState(() => _route = route);
    } catch (error) {
      if (mounted) setState(() => _error = 'Route unavailable: \$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _centerOnPosition() {
    final position = _position;
    if (position != null) _mapController.move(position, 16);
  }

  @override Widget build(BuildContext context) {
    final position = _position;
    return Scaffold(
      appBar: AppBar(
        title: const Text('6 Vitesses • Map'),
        actions: [IconButton(onPressed: _centerOnPosition, icon: const Icon(Icons.my_location), tooltip: 'My location')],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: position ?? const LatLng(34.0209, -6.8416),
            initialZoom: position == null ? 6 : 16,
            onLongPress: (_, point) => _routeTo(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.sixvitesses',
            ),
            if (_route != null)
              PolylineLayer(polylines: [
                Polyline(points: _route!.geometry, strokeWidth: 5, color: Colors.blueAccent),
              ]),
            MarkerLayer(markers: [
              if (position != null)
                Marker(point: position, width: 44, height: 44, child: const Icon(Icons.navigation, size: 36, color: Colors.blue)),
              if (_destination != null)
                Marker(point: _destination!, width: 44, height: 44, child: const Icon(Icons.location_on, size: 38, color: Colors.red)),
            ]),
            RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
        if (_loading) const Positioned(
          top: 12, left: 12,
          child: Card(child: Padding(padding: EdgeInsets.all(10), child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8), Text('Loading…'),
          ]))),
        ),
        if (_error != null) Positioned(left: 12, right: 12, bottom: 12, child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text(_error!)))),
        if (_route != null) Positioned(left: 12, top: 12, child: Card(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text('\${(_route!.distanceMeters / 1000).toStringAsFixed(1)} km • \${(_route!.durationSeconds / 60).round()} min', style: const TextStyle(fontWeight: FontWeight.w700)),
        ))),
        Positioned(right: 12, bottom: 12, child: Card(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text('Long-press map to route\\n© OpenStreetMap contributors', textAlign: TextAlign.center),
        ))),
      ]),
    );
  }

  @override void dispose() {
    _positionSub?.cancel();
    _routeService.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
