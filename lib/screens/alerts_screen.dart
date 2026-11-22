import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vesta_app/services/alert_read_state.dart';
import 'package:vesta_app/services/notification_service.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/alert_text.dart';
import 'package:vesta_app/l10n/tr.dart';
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

enum _Filter { all, critical, warning, info }

class _AlertsScreenState extends State<AlertsScreen> {
  static const int _pageSize = 100;

  static const Color _critical = VestaTheme.danger;
  static const Color _warning = VestaTheme.warning;
  static const Color _info = VestaTheme.info;

  _Filter _filter = _Filter.all;
  DateTime? _seenAt;
  bool _initialSnapshot = true;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      _alertsCollection
          .orderBy('timestamp', descending: true)
          .limit(_pageSize)
          .snapshots();

  CollectionReference<Map<String, dynamic>> get _alertsCollection =>
      FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('alerts');

  @override
  void initState() {
    super.initState();
    // Keep the previous mark to highlight what is new on this visit.
    AlertReadState.lastSeen(widget.childId).then((value) {
      if (mounted) setState(() => _seenAt = value);
    });
  }

  /// Local notice for alerts that arrive while the screen is open. If the FCM
  /// push already showed the same alert, NotificationService drops it.
  void _notifyNewAlerts(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_initialSnapshot) {
      _initialSnapshot = false;
      return;
    }
    if (snapshot.metadata.isFromCache) return;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data();
      if (data == null) continue;

      final text = AlertText.of(data);
      NotificationService.instance.mostrarNotificacionInmediata(
        titulo: text.title,
        subtitulo: text.body,
        tipo: data['type']?.toString() ?? 'critical',
        alertId: change.doc.id,
        childId: widget.childId,
      );
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VestaTheme.wine),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _eliminarAlerta(String alertId) async {
    try {
      await _alertsCollection.doc(alertId).delete();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('No se pudo eliminar la alerta: {0}', [error]))),
      );
    }
  }

  Future<void> _eliminarTodas(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final ok = await _confirm(
      tr('Eliminar {0} alertas', [docs.length]),
      tr('Se eliminarán las alertas mostradas para todos los tutores. Esta acción no se puede deshacer.'),
      tr('Eliminar'),
    );
    if (!ok || !mounted) return;

    try {
      for (var i = 0; i < docs.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('No se pudieron eliminar: {0}', [error]))),
      );
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$lat,$lng',
    });
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo abrir el mapa.'))),
        );
      }
    }
  }

  bool _matches(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? 'critical';
    return switch (_filter) {
      _Filter.all => true,
      _Filter.critical => type == 'critical',
      _Filter.warning => type == 'warning',
      _Filter.info => type != 'critical' && type != 'warning',
    };
  }

  static Color _colorFor(String? type) => switch (type) {
        'warning' => _warning,
        'info' => _info,
        _ => _critical,
      };

  static IconData _iconFor(String? eventKey) => switch (eventKey) {
        'battery_low' || 'battery_critical' => Icons.battery_alert_rounded,
        'speed' => Icons.speed_rounded,
        'blocked_app' => Icons.block_rounded,
        'blocked_domain' => Icons.public_off_rounded,
        'study_mode_block' => Icons.menu_book_rounded,
        'offline_period' || 'device_offline' => Icons.wifi_off_rounded,
        'location_disabled' ||
        'location_permission_revoked' =>
          Icons.location_off_rounded,
        'location_enabled' => Icons.location_on_rounded,
        'accessibility_disabled' || 'vpn_revoked' => Icons.gpp_bad_rounded,
        'sos' => Icons.sos_rounded,
        'zone_enter' => Icons.login_rounded,
        'zone_exit' => Icons.logout_rounded,
        'app_limit_reached' => Icons.timer_off_rounded,
        _ => Icons.notification_important_rounded,
      };

  String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return tr('Ahora');
    if (diff.inMinutes < 60) return tr('Hace {0} min', [diff.inMinutes]);
    if (diff.inHours < 24) return tr('Hace {0} h', [diff.inHours]);
    if (diff.inDays == 1) return tr('Ayer · {0}', [DateFormat('HH:mm').format(date)]);
    return DateFormat('dd/MM/yyyy · HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) _notifyNewAlerts(snapshot.data!);

          if (snapshot.hasError && !snapshot.hasData) {
            return _message(
              Icons.lock_outline_rounded,
              tr('No se pudieron cargar las alertas. Comprueba que todos los tutores han autorizado las alertas.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: VestaTheme.rose),
            );
          }

          final allDocs = snapshot.data!.docs;
          final docs = allDocs.where((doc) => _matches(doc.data())).toList();
          final criticalCount = allDocs
              .where((doc) => (doc.data()['type'] ?? 'critical') == 'critical')
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      allDocs.isEmpty
                          ? tr('Sin alertas')
                          : tr('{0} alertas · {1} críticas', [allDocs.length, criticalCount]),
                      style: TextStyle(
                        color: VestaTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (docs.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _eliminarTodas(docs),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: Text(tr('Vaciar')),
                    ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (filter, label) in [
                      (_Filter.all, tr('Todas')),
                      (_Filter.critical, tr('Críticas')),
                      (_Filter.warning, tr('Avisos')),
                      (_Filter.info, tr('Informativas')),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: docs.isEmpty
                    ? _message(
                        Icons.verified_user_rounded,
                        allDocs.isEmpty
                            ? tr('Sin incidentes reportados.')
                            : tr('No hay alertas de este tipo.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          return _buildAlertaCard(doc.id, doc.data());
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: VestaTheme.textSecondary),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: VestaTheme.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _buildAlertaCard(String alertId, Map<String, dynamic> data) {
    final text = AlertText.of(data);
    final type = data['type']?.toString();
    final accent = _colorFor(type);
    final date = AlertReadState.alertDate(data);
    final unread = AlertReadState.isUnread(data, _seenAt);

    return Dismissible(
      key: ValueKey(alertId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: VestaTheme.wine,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirm(
        tr('Eliminar alerta'),
        tr('¿Seguro que deseas eliminar esta alerta?'),
        tr('Eliminar'),
      ),
      onDismissed: (_) => _eliminarAlerta(alertId),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: VestaTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread
                ? accent.withValues(alpha: 0.6)
                : VestaTheme.beige.withValues(alpha: 0.10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(data['eventKey']?.toString()),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            text.title,
                            style: TextStyle(
                              color: VestaTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tr('NUEVA'),
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text.body,
                      style: TextStyle(
                        color: VestaTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    if (data['lat'] is num && data['lng'] is num)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openMap(
                            (data['lat'] as num).toDouble(),
                            (data['lng'] as num).toDouble(),
                          ),
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: Text(
                            data['eventKey'] == 'sos'
                                ? tr('Ver dónde está ahora')
                                : tr('Ver en el mapa'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: VestaTheme.textSecondary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          date == null ? tr('Fecha no disponible') : _relative(date),
                          style: TextStyle(
                            color: VestaTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
