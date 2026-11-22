import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Safe zones (home, school...). Vesta Tracker notifies on entering or leaving.
/// Requires the guardians to have authorised location.
class ZonesScreen extends StatelessWidget {
  final String childId;

  const ZonesScreen({super.key, required this.childId});

  static const int maxZones = 10;

  CollectionReference<Map<String, dynamic>> get _zones =>
      FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .collection('zones');

  Future<void> _edit(
    BuildContext context, {
    String? zoneId,
    Map<String, dynamic>? data,
  }) async {
    LatLng? initial;
    if (data == null) {
      // Centre on the minor's last known location.
      try {
        final telemetry = await FirebaseFirestore.instance
            .collection('telemetria')
            .doc(childId)
            .get();
        final lat = telemetry.data()?['lat'];
        final lng = telemetry.data()?['lng'];
        if (lat is num && lng is num) {
          initial = LatLng(lat.toDouble(), lng.toDouble());
        }
      } catch (_) {}
    }
    if (!context.mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ZoneEditor(
        collection: _zones,
        zoneId: zoneId,
        data: data,
        initialCenter: initial,
      ),
    ));
  }

  Future<void> _delete(BuildContext context, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('¿Eliminar "{0}"?', [name])),
        content: Text(tr('Dejarás de recibir avisos de esta zona.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Eliminar')),
          ),
        ],
      ),
    );
    if (ok == true) await _zones.doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(title: Text(tr('Zonas seguras'))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _zones.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Las zonas requieren que todos los tutores autoricen la ubicación.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VestaTheme.textSecondary),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Text(
                tr('Recibirás un aviso cuando llegue o salga de estas zonas. Funciona aunque el teléfono esté un rato sin conexión: el aviso llega al reconectar.'),
                style: TextStyle(color: VestaTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      tr('Todavía no hay zonas. Empieza por "Casa" o "Colegio".'),
                      style: TextStyle(color: VestaTheme.textSecondary),
                    ),
                  ),
                ),
              for (final doc in docs)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.place_rounded, color: VestaTheme.rose),
                    title: Text(doc.data()['name']?.toString() ?? tr('Zona')),
                    subtitle: Text(
                      tr('Radio {0} m · {1}', [(doc.data()['radius'] as num?)?.round() ?? '?', [
                        if (doc.data()['notifyEnter'] != false) 'llegadas',
                        if (doc.data()['notifyExit'] != false) 'salidas',
                      ].join(' y ')]),
                    ),
                    onTap: () => _edit(context, zoneId: doc.id, data: doc.data()),
                    trailing: IconButton(
                      tooltip: tr('Eliminar'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _delete(
                        context,
                        doc.id,
                        doc.data()['name']?.toString() ?? tr('Zona'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _zones.snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          if (snapshot.hasError || count >= maxZones) return const SizedBox();
          return FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_location_alt_rounded),
            label: Text(tr('Nueva zona')),
          );
        },
      ),
    );
  }
}

class _ZoneEditor extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> collection;
  final String? zoneId;
  final Map<String, dynamic>? data;
  final LatLng? initialCenter;

  const _ZoneEditor({
    required this.collection,
    this.zoneId,
    this.data,
    this.initialCenter,
  });

  @override
  State<_ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<_ZoneEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.data?['name']?.toString() ?? '',
  );
  late LatLng? _center = widget.data != null
      ? LatLng(
          (widget.data!['lat'] as num).toDouble(),
          (widget.data!['lng'] as num).toDouble(),
        )
      : widget.initialCenter;
  late double _radius = (widget.data?['radius'] as num?)?.toDouble() ?? 200;
  late bool _enter = widget.data?['notifyEnter'] != false;
  late bool _exit = widget.data?['notifyExit'] != false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final center = _center;
    if (name.isEmpty || name.length > 40 || center == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Pon un nombre (máx. 40) y toca el mapa para fijar el centro.')),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final data = {
      'name': name,
      'lat': center.latitude,
      'lng': center.longitude,
      'radius': _radius.roundToDouble(),
      'notifyEnter': _enter,
      'notifyExit': _exit,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
    };

    try {
      final ref = widget.zoneId == null
          ? widget.collection.doc()
          : widget.collection.doc(widget.zoneId);
      await ref.set(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo guardar la zona: {0}', [e]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;

    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(
        title: Text(widget.zoneId == null ? tr('Nueva zona') : tr('Editar zona')),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(tr('Guardar')),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center ?? const LatLng(4.6, -74.08),
                initialZoom: center == null ? 5 : 16,
                onTap: (_, point) => setState(() => _center = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.vestaopensource.tutor',
                ),
                if (center != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: center,
                      radius: _radius,
                      useRadiusInMeter: true,
                      color: VestaTheme.rose.withValues(alpha: 0.18),
                      borderColor: VestaTheme.rose,
                      borderStrokeWidth: 2,
                    ),
                  ]),
                if (center != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: center,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.place_rounded,
                          color: VestaTheme.wine, size: 40),
                    ),
                  ]),
                RichAttributionWidget(attributions: [
                  TextSourceAttribution(tr('© OpenStreetMap contributors')),
                ]),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (center == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tr('Toca el mapa para fijar el centro de la zona.'),
                        style: TextStyle(color: VestaTheme.textSecondary),
                      ),
                    ),
                  TextField(
                    controller: _name,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: tr('Nombre (Casa, Colegio...)'),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(tr('Radio: {0} m', [_radius.round()]),
                          style: TextStyle(color: VestaTheme.textPrimary)),
                      Expanded(
                        child: Slider(
                          value: _radius,
                          min: 50,
                          max: 2000,
                          divisions: 39,
                          onChanged: (value) => setState(() => _radius = value),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: FilterChip(
                          label: Text(tr('Avisar al llegar')),
                          selected: _enter,
                          onSelected: (v) => setState(() => _enter = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilterChip(
                          label: Text(tr('Avisar al salir')),
                          selected: _exit,
                          onSelected: (v) => setState(() => _exit = v),
                        ),
                      ),
                    ],
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
