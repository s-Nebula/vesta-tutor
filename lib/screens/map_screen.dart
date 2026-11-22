import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vesta_app/screens/zones_screen.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
class MapScreen extends StatefulWidget {
  final String childId;
  final String tutorId;

  const MapScreen({super.key, required this.childId, required this.tutorId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng _ultimaUbicacion = const LatLng(11.2404, -74.1990);
  String _lastUpdate = tr('Esperando señal...');
  bool _hayUbicacion = false;
  bool _mapReady = false;
  DateTime? _lastFix;
  String? _error;
  Timer? _staleTimer;
  StreamSubscription? _locationSubscription;

  static const Duration _staleAfter = Duration(minutes: 15);

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _zonesStream =
      FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('zones')
          .snapshots();

  @override
  void initState() {
    super.initState();
    _iniciarEscuchaUbicacion();
    // Refreshes the "old signal" notice even when no new data arrives.
    _staleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _lastFix != null) setState(() {});
    });
  }

  Future<void> _abrirGoogleMaps() async {
    if (!_hayUbicacion) return;

    final destination =
        '${_ultimaUbicacion.latitude},${_ultimaUbicacion.longitude}';

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
      'travelmode': 'driving',
    });

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo abrir Google Maps'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al abrir Google Maps'))),
        );
      }
    }
  }

  void _iniciarEscuchaUbicacion() {
    _locationSubscription = FirebaseFirestore.instance
        .collection('telemetria')
        .doc(widget.childId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;

      final data = snapshot.data();
      final lat = data?['lat'] as num?;
      final lng = data?['lng'] as num?;
      // Actual capture time (the device may send late if it was offline);
      // otherwise the time it reached the server.
      final captured = data?['capturedAt'];
      final server = data?['timestamp'];
      final fix = captured is Timestamp
          ? captured.toDate()
          : server is Timestamp
              ? server.toDate()
              : null;

      if (lat == null ||
          lng == null ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        return;
      }

      final newPos = LatLng(lat.toDouble(), lng.toDouble());

      setState(() {
        _error = null;
        _ultimaUbicacion = newPos;
        _hayUbicacion = true;
        _lastFix = fix;
        _lastUpdate = fix == null
            ? tr('Sin hora')
            : DateFormat('dd/MM HH:mm:ss').format(fix);
      });

      if (_mapReady) _mapController.move(newPos, _mapController.camera.zoom);
    }, onError: (Object error) {
      if (!mounted) return;
      setState(() {
        _error = tr('No se puede acceder a la ubicación. Comprueba que todos los tutores han autorizado la ubicación.');
      });
    });
  }

  bool get _isStale =>
      _lastFix != null && DateTime.now().difference(_lastFix!) > _staleAfter;

  String _staleMinutes() {
    final diff = DateTime.now().difference(_lastFix!);
    if (diff.inHours >= 1) return tr('{0} h {1} min', [diff.inHours, diff.inMinutes % 60]);
    return '${diff.inMinutes} min';
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _staleTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = VestaTheme.isDark;

    const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Rastreo en Tiempo Real'),
                style: TextStyle(fontSize: 16)),
            Text(tr('Última señal: {0}', [_lastUpdate]),
                style: TextStyle(fontSize: 12, color: VestaTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('Zonas seguras'),
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ZonesScreen(childId: widget.childId),
            )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _hayUbicacion ? _abrirGoogleMaps : null,
        icon: const Icon(Icons.directions),
        label: Text(tr('Cómo llegar')),
      ),
      body: Container(
        color: isDarkMode ? const Color(0xFF121212) : Colors.white,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _ultimaUbicacion,
            initialZoom: 16.0,
            onMapReady: () {
              _mapReady = true;
              if (_hayUbicacion) _mapController.move(_ultimaUbicacion, 16.0);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'org.vestaopensource.tutor',
              retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
              keepBuffer: 6,
              tileSize: 256,
              tileProvider: NetworkTileProvider(),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _zonesStream,
              builder: (context, snapshot) {
                final circles = <CircleMarker>[];
                for (final doc in snapshot.data?.docs ?? const []) {
                  final data = doc.data();
                  final lat = data['lat'], lng = data['lng'], r = data['radius'];
                  if (lat is num && lng is num && r is num) {
                    circles.add(CircleMarker(
                      point: LatLng(lat.toDouble(), lng.toDouble()),
                      radius: r.toDouble(),
                      useRadiusInMeter: true,
                      color: VestaTheme.success.withValues(alpha: 0.12),
                      borderColor: VestaTheme.success,
                      borderStrokeWidth: 2,
                    ));
                  }
                }
                return CircleLayer(circles: circles);
              },
            ),
            if (_hayUbicacion) MarkerLayer(
              markers: [
                Marker(
                  point: _ultimaUbicacion,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.person_pin_circle,
                    color: VestaTheme.rose,
                    size: 40,
                  ),
                ),
              ],
            ),
            if (_error != null || !_hayUbicacion || _isStale)
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _error != null
                        ? const Color(0xFF792D43)
                        : const Color(0xFF8A5A00),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error ??
                        (!_hayUbicacion
                            ? tr('Todavía no hay ninguna ubicación del dispositivo.')
                            : tr('Última ubicación conocida hace {0}. El dispositivo puede estar sin conexión o con la ubicación desactivada.', [_staleMinutes()])),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(tr('© OpenStreetMap contributors')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
