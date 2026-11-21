import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme_notifier.dart';

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
  String _lastUpdate = "Esperando señal...";
  bool _hayUbicacion = false;
  StreamSubscription? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _iniciarEscuchaUbicacion();
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
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al abrir Google Maps')),
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
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        final lat = data?['lat'] as num?;
        final lng = data?['lng'] as num?;
        final timestamp = data?['timestamp'] as Timestamp?;

        if (lat != null &&
            lng != null &&
            lat >= -90 &&
            lat <= 90 &&
            lng >= -180 &&
            lng <= 180) {
          final newPos = LatLng(lat.toDouble(), lng.toDouble());

          setState(() {
            _ultimaUbicacion = newPos;
            _hayUbicacion = true;
            if (timestamp != null) {
              _lastUpdate = DateFormat('HH:mm:ss').format(timestamp.toDate());
            } else {
              _lastUpdate = DateFormat('HH:mm:ss').format(DateTime.now());
            }
          });

          _mapController.move(newPos, 16.0);
        }
      }
    });
  }

  void _mostrarModalTema(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Consumer<ThemeNotifier>(
          builder: (context, themeNotifier, child) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Seleccionar Tema",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  RadioListTile<ThemeMode>(
                    title: const Text("Tema Claro"),
                    value: ThemeMode.light,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (value) {
                      themeNotifier.setTheme(value!);
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text("Tema Oscuro"),
                    value: ThemeMode.dark,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (value) {
                      themeNotifier.setTheme(value!);
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text("Predeterminado del Sistema"),
                    value: ThemeMode.system,
                    groupValue: themeNotifier.themeMode,
                    onChanged: (value) {
                      themeNotifier.setTheme(value!);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    bool isDarkMode = themeNotifier.themeMode == ThemeMode.dark ||
        (themeNotifier.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Rastreo en Tiempo Real",
                style: TextStyle(fontSize: 16)),
            Text("Última señal: $_lastUpdate",
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => _mostrarModalTema(context),
            tooltip: "Cambiar tema",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _hayUbicacion ? _abrirGoogleMaps : null,
        icon: const Icon(Icons.directions),
        label: const Text('Cómo llegar'),
      ),
      body: Container(
        color: isDarkMode ? const Color(0xFF121212) : Colors.white,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _ultimaUbicacion,
            initialZoom: 16.0,
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'org.vestaopensource.tracker',
              retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
              keepBuffer: 6,
              tileSize: 256,
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _ultimaUbicacion,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.person_pin_circle,
                    color: Color(0xFFE03131),
                    size: 40,
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
