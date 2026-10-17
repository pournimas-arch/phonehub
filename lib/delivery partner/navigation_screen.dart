import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:phonehub/delivery%20partner/app_theme.dart';
import 'package:phonehub/delivery%20partner/common.dart';
import 'package:phonehub/delivery%20partner/orders_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'confirm_delivery_screen.dart';
import 'package:phonehub/app_text.dart';

/// Screen 4 – Navigation (3h)
/// Map with the customer's location, live distance and ETA, address card, Open in Google Maps button.
/// The map, distance and time use the customer's saved delivery point (order.lat / order.lng)
/// and the partner's GPS. Orders without a saved point show the plain map picture and open
/// Google Maps with the written address.
class NavigationScreen extends StatefulWidget {
  final DeliveryOrder order;
  final bool showBack;
  const NavigationScreen({super.key, required this.order, this.showBack = true});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  static const double _avgKmPerHour = 25; // city bike / scooter speed used for the ETA

  StreamSubscription<Position>? _sub;
  gm.GoogleMapController? _map;
  gm.LatLng? _me;
  bool _canShowMe = false;
  bool _fitted = false;

  DeliveryOrder get order => widget.order;
  bool get _hasDest => order.lat != null && order.lng != null;
  gm.LatLng? get _dest => _hasDest ? gm.LatLng(order.lat!, order.lng!) : null;

  @override
  void initState() {
    super.initState();
    _startLocation();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      if (!mounted) return;
      setState(() => _canShowMe = true);
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _onPosition(last);
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
      ).listen(_onPosition, onError: (Object _) {});
    } catch (_) {}
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    setState(() => _me = gm.LatLng(p.latitude, p.longitude));
    _fit();
  }

  /// Shows both the partner and the customer on the map (once, so the partner can still move the map).
  void _fit() {
    final me = _me, dest = _dest, map = _map;
    if (_fitted || me == null || dest == null || map == null) return;
    _fitted = true;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final bounds = gm.LatLngBounds(
        southwest: gm.LatLng(math.min(me.latitude, dest.latitude), math.min(me.longitude, dest.longitude)),
        northeast: gm.LatLng(math.max(me.latitude, dest.latitude), math.max(me.longitude, dest.longitude)),
      );
      map.animateCamera(gm.CameraUpdate.newLatLngBounds(bounds, 90)).catchError((Object _) {});
    });
  }

  double? get _km {
    final me = _me, dest = _dest;
    if (me == null || dest == null) return null;
    return Geolocator.distanceBetween(me.latitude, me.longitude, dest.latitude, dest.longitude) / 1000;
  }

  String get _etaText {
    final km = _km;
    if (km == null) return '--';
    return math.max(1, (km / _avgKmPerHour * 60).ceil()).toString();
  }

  String get _distText {
    final km = _km;
    if (km == null) return '--';
    return km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
  }

  /// Opens Google Maps turn-by-turn navigation to the customer.
  Future<void> _openGoogleMaps() async {
    final uris = <Uri>[
      if (_hasDest) Uri.parse('google.navigation:q=${order.lat},${order.lng}&mode=d'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
            '${_hasDest ? '${order.lat},${order.lng}' : Uri.encodeComponent(order.address)}&travelmode=driving',
      ),
    ];
    for (final uri in uris) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (mounted) _snack('Could not open Google Maps. Please install or update it.');
  }

  Widget _buildMap() {
    final dest = _dest;
    if (dest == null) return const MapPlaceholder();
    final me = _me;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: dest, zoom: 15),
      onMapCreated: (c) {
        _map = c;
        _fit();
      },
      markers: {
        gm.Marker(
          markerId: const gm.MarkerId('customer'),
          position: dest,
          infoWindow: gm.InfoWindow(title: order.customer, snippet: order.area),
        ),
      },
      polylines: {
        if (me != null)
          gm.Polyline(
            polylineId: const gm.PolylineId('route'),
            points: [me, dest],
            color: AppColors.primary,
            width: 4,
            patterns: [gm.PatternItem.dash(18), gm.PatternItem.gap(10)],
          ),
      },
      myLocationEnabled: _canShowMe,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  /// Moves the map to the partner (or the customer when GPS is not available).
  Future<void> _recenter() async {
    final map = _map;
    final target = _me ?? _dest;
    if (map == null || target == null) return;
    try {
      await map.animateCamera(gm.CameraUpdate.newLatLngZoom(target, 16));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final eta = _etaText == '--' ? '--' : '$_etaText min';
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B5E57), AppColors.primary]),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(widget.showBack ? 6 : 18, 10, 16, 14),
                child: Row(
                  children: [
                    if (widget.showBack)
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    const Text('Navigate', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildMap()),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: GestureDetector(
                    onTap: _recenter,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)]),
                      child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -8))],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), shape: BoxShape.circle),
                        child: const Icon(Icons.location_on_rounded, color: AppColors.danger, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To: ${order.customer}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppText.body)),
                            const SizedBox(height: 2),
                            Text('$_distText  •  $eta', style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(order.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: AppText.small, height: 1.3)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: _openGoogleMaps,
                    icon: const Icon(Icons.navigation_rounded, size: 20),
                    label: const Text('Start Navigation', style: TextStyle(fontSize: AppText.subtitle)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmDeliveryScreen(order: order))),
                    child: const Text('Reached • Confirm Delivery', style: TextStyle(fontSize: AppText.body)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}