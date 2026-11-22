import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Daily time limits per app
/// (`children/{id}/controls/app_limits`).
///
/// Vesta Tracker measures today's usage on the phone itself and blocks the app
/// when the time runs out; the minor can ask for more from the notice.
class AppLimitsScreen extends StatefulWidget {
  final String childId;

  const AppLimitsScreen({super.key, required this.childId});

  @override
  State<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends State<AppLimitsScreen> {
  static const _options = [15, 30, 45, 60, 90, 120, 180, 240];

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance
      .collection('children')
      .doc(widget.childId)
      .collection('controls')
      .doc('app_limits');

  String _query = '';

  Future<void> _setLimit(Map<String, int> current, String pkg, int? minutes) async {
    final limits = {...current};
    if (minutes == null) {
      limits.remove(pkg);
    } else {
      limits[pkg] = minutes;
    }
    try {
      await _ref.set({
        'limits': limits,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo guardar el límite: {0}', [e]))),
        );
      }
    }
  }

  Future<void> _pick(Map<String, int> current, String pkg, String name) async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(tr('Límite diario para {0}', [name])),
        children: [
          for (final minutes in _options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, minutes),
              child: Text(_label(minutes)),
            ),
          if (current.containsKey(pkg))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, -1),
              child: Text(
                tr('Quitar límite'),
                style: TextStyle(color: VestaTheme.rose),
              ),
            ),
        ],
      ),
    );
    if (result == null) return;
    await _setLimit(current, pkg, result == -1 ? null : result);
  }

  static String _label(int minutes) {
    if (minutes < 60) return tr('{0} min al día', [minutes]);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? tr('{0} h al día', [h]) : tr('{0} h {1} min al día', [h, m]);
  }

  static String _duration(int ms) {
    final minutes = (ms / 60000).round();
    if (minutes < 60) return '$minutes min';
    return tr('{0} h {1} min', [minutes ~/ 60, minutes % 60]);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final childRef =
        FirebaseFirestore.instance.collection('children').doc(widget.childId);

    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(title: Text(tr('Límites de tiempo'))),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, limitsSnap) {
          if (limitsSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Los límites requieren autorización de control de aplicaciones.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VestaTheme.textSecondary),
                ),
              ),
            );
          }

          final raw = limitsSnap.data?.data()?['limits'];
          final limits = <String, int>{
            if (raw is Map)
              for (final entry in raw.entries)
                if (entry.value is num) entry.key.toString(): (entry.value as num).toInt(),
          };

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            // Today's usage (if the guardians authorised usage statistics).
            stream: childRef.collection('usage_reports').doc(today).snapshots(),
            builder: (context, usageSnap) {
              final usage = <String, int>{};
              final apps = usageSnap.data?.data()?['apps'];
              if (apps is List) {
                for (final app in apps.whereType<Map>()) {
                  final pkg = app['packageName']?.toString();
                  final ms = app['foregroundTimeMs'];
                  if (pkg != null && ms is num) usage[pkg] = ms.toInt();
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: childRef
                    .collection('installed_apps')
                    .where('isInstalled', isEqualTo: true)
                    .snapshots(),
                builder: (context, appsSnap) {
                  if (!appsSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final query = _query.toLowerCase();
                  final list = appsSnap.data!.docs
                      .map((d) => d.data())
                      .where((a) =>
                          query.isEmpty ||
                          (a['appName'] ?? '').toString().toLowerCase().contains(query))
                      .toList()
                    ..sort((a, b) {
                      final la = limits.containsKey(a['packageName']);
                      final lb = limits.containsKey(b['packageName']);
                      if (la != lb) return la ? -1 : 1;
                      final ua = usage[a['packageName']] ?? 0;
                      final ub = usage[b['packageName']] ?? 0;
                      if (ua != ub) return ub.compareTo(ua);
                      return (a['appName'] ?? '').toString().compareTo(
                            (b['appName'] ?? '').toString(),
                          );
                    });

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Text(
                        tr('Cuando se agota el tiempo, la app se bloquea hasta mañana. Tu hijo puede pedirte más tiempo y lo apruebas con un toque.'),
                        style: TextStyle(color: VestaTheme.textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: tr('Buscar aplicación'),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 8),
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            tr('Todavía no hay aplicaciones sincronizadas.'),
                            style: TextStyle(color: VestaTheme.textSecondary),
                          ),
                        ),
                      for (final app in list) _tile(app, limits, usage),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _tile(
    Map<String, dynamic> app,
    Map<String, int> limits,
    Map<String, int> usage,
  ) {
    final pkg = (app['packageName'] ?? '').toString();
    final name = (app['appName'] ?? pkg).toString();
    final limit = limits[pkg];
    final used = usage[pkg] ?? 0;
    final icon = (app['iconBase64'] ?? '').toString();

    Widget leading = const Icon(Icons.android_rounded);
    if (icon.isNotEmpty) {
      try {
        leading = Image.memory(base64Decode(icon), width: 34, height: 34, gaplessPlayback: true);
      } catch (_) {}
    }

    final progress = limit == null ? null : (used / (limit * 60000)).clamp(0.0, 1.0);

    return Card(
      child: ListTile(
        leading: leading,
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              limit == null
                  ? tr('Sin límite · hoy {0}', [_duration(used)])
                  : tr('{0} · hoy {1}', [_label(limit), _duration(used)]),
              style: TextStyle(color: VestaTheme.textSecondary, fontSize: 12),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                color: progress >= 1 ? VestaTheme.danger : VestaTheme.rose,
                backgroundColor: VestaTheme.surfaceLight,
              ),
            ],
          ],
        ),
        trailing: Icon(
          limit == null ? Icons.timer_outlined : Icons.timer_rounded,
          color: limit == null ? VestaTheme.textSecondary : VestaTheme.rose,
        ),
        onTap: () => _pick(limits, pkg, name),
      ),
    );
  }
}
