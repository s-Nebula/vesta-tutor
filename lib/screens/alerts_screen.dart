import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vesta_app/services/notification_service.dart';

class AlertsScreen extends StatefulWidget {
  final String childId;
  final String tutorId;

  const AlertsScreen({
    super.key,
    required this.childId,
    required this.tutorId,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final NotificationService _notificationService = NotificationService();

  String? _ultimoAlertIdProcesado;
  bool _alertasInicializadas = false;

  CollectionReference<Map<String, dynamic>> get _alertsCollection =>
      FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('alerts');

  Future<void> _eliminarAlerta(String alertId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF222630),
        title: const Text(
          'Eliminar alerta',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Seguro que deseas eliminar esta alerta? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Color(0xFFE03131)),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      await _alertsCollection.doc(alertId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alerta eliminada correctamente'),
          backgroundColor: Color(0xFF2B8A3E),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar la alerta: $error'),
          backgroundColor: const Color(0xFFE03131),
        ),
      );
    }
  }

  DateTime? _obtenerFecha(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VESTA SECURITY & TRACKING',
            style: TextStyle(
              color: Color(0xFFE03131),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _alertsCollection
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE03131),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error al cargar alertas: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sin incidentes reportados',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                final ultimaAlertaDoc = docs.first;

                if (!_alertasInicializadas) {
                  _alertasInicializadas = true;
                  _ultimoAlertIdProcesado = ultimaAlertaDoc.id;
                } else if (_ultimoAlertIdProcesado != ultimaAlertaDoc.id) {
                  final esNuevaAlerta = snapshot.data!.docChanges.any(
                    (change) =>
                        change.type == DocumentChangeType.added &&
                        change.doc.id == ultimaAlertaDoc.id,
                  );

                  _ultimoAlertIdProcesado = ultimaAlertaDoc.id;

                  if (esNuevaAlerta) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;

                      final data = ultimaAlertaDoc.data();
                      _notificationService.mostrarNotificacionInmediata(
                        titulo: data['title'] ?? 'Alerta',
                        subtitulo:
                            data['subtitle'] ?? 'Incidente registrado',
                        tipo: data['type'] ?? 'critical',
                      );
                    });
                  }
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _buildAlertaCard(doc.id, doc.data());
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaCard(String alertId, Map<String, dynamic> data) {
    final accentColor = data['type'] == 'critical'
        ? const Color(0xFFE03131)
        : const Color(0xFFFCC419);

    final fecha = _obtenerFecha(data['timestamp']);
    final fechaTexto = fecha == null
        ? 'Fecha no disponible'
        : DateFormat('dd/MM/yyyy · HH:mm').format(fecha);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF222630),
        border: Border.all(color: const Color(0xFF3A3F4D)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 76, color: accentColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? 'Alerta',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data['subtitle'] ?? '',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white54,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        fechaTexto,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Eliminar alerta',
            onPressed: () => _eliminarAlerta(alertId),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
