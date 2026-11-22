import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Requests from the minor ("more time", "unlock app").
///
/// When approved, the minor's phone gets a temporary permission for that app
/// for the granted minutes, even if it is blocked, in study mode or out of
/// daily time.
class RequestsScreen extends StatelessWidget {
  final String childId;

  const RequestsScreen({super.key, required this.childId});

  static Query<Map<String, dynamic>> pendingQuery(String childId) =>
      FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .collection('requests')
          .where('status', isEqualTo: 'pending');

  CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .collection('requests');

  Future<void> _approve(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    int requested,
  ) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('¿Cuánto tiempo concedes?')),
        children: [
          for (final option in {requested, 15, 30, 60, 120}.toList()..sort())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, option),
              child: Text(
                option == requested ? tr('{0} min (lo que pidió)', [option]) : '$option min',
                style: TextStyle(
                  fontWeight: option == requested ? FontWeight.w800 : null,
                ),
              ),
            ),
        ],
      ),
    );
    if (minutes == null || !context.mounted) return;

    try {
      await ref.update({
        'status': 'approved',
        'grantedMinutes': minutes,
        'approvedUntil': Timestamp.fromDate(
          DateTime.now().add(Duration(minutes: minutes)),
        ),
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Aprobado durante {0} minutos.', [minutes]))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo responder: {0}', [e]))),
        );
      }
    }
  }

  Future<void> _deny(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      await ref.update({
        'status': 'denied',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo responder: {0}', [e]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(title: Text(tr('Peticiones'))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requests.orderBy('createdAt', descending: true).limit(50).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Las peticiones requieren autorización de control de aplicaciones.'),
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
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Cuando tu hijo pida más tiempo o usar una app bloqueada, aparecerá aquí y te llegará una notificación.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VestaTheme.textSecondary, height: 1.5),
                ),
              ),
            );
          }

          final pending = docs.where((d) => d.data()['status'] == 'pending');
          final resolved = docs.where((d) => d.data()['status'] != 'pending');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final doc in pending) _card(context, doc, pending: true),
              if (resolved.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    tr('HISTORIAL'),
                    style: TextStyle(
                      color: VestaTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                for (final doc in resolved) _card(context, doc, pending: false),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _card(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required bool pending,
  }) {
    final data = doc.data();
    final app = data['appName']?.toString() ?? data['packageName']?.toString() ?? tr('App');
    final minutes = (data['minutes'] as num?)?.toInt() ?? 30;
    final created = data['createdAt'];
    final when = created is Timestamp
        ? DateFormat('dd/MM HH:mm').format(created.toDate())
        : '';
    final status = data['status'];
    final title = data['type'] == 'extra_time'
        ? tr('Pide {0} min más de {1}', [minutes, app])
        : tr('Pide usar {0} durante {1} min', [app, minutes]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pending
                      ? Icons.front_hand_rounded
                      : status == 'approved'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                  color: pending
                      ? VestaTheme.warning
                      : status == 'approved'
                          ? VestaTheme.success
                          : VestaTheme.rose,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: VestaTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if ((data['message'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"${data['message']}"',
                style: TextStyle(
                  color: VestaTheme.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              pending
                  ? when
                  : status == 'approved'
                      ? tr('{0} · aprobada ({1} min)', [when, data['grantedMinutes']])
                      : tr('{0} · rechazada', [when]),
              style: TextStyle(color: VestaTheme.textSecondary, fontSize: 12),
            ),
            if (pending) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _deny(context, doc.reference),
                      child: Text(tr('Rechazar')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _approve(context, doc.reference, minutes),
                      child: Text(tr('Aprobar')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
