import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vesta_app/services/age_presets.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
/// SafeSearch, encrypted DNS blocking and age recommendations.
///
/// Stored in `children/{id}/controls/web_protection` and applied by
/// Vesta Tracker's DNS VPN.
class WebProtectionCard extends StatelessWidget {
  final String childId;

  const WebProtectionCard({super.key, required this.childId});

  DocumentReference<Map<String, dynamic>> get _childRef =>
      FirebaseFirestore.instance.collection('children').doc(childId);

  DocumentReference<Map<String, dynamic>> get _ref =>
      _childRef.collection('controls').doc('web_protection');

  Future<void> _save(
    BuildContext context, {
    required bool safeSearch,
    required bool blockDoh,
  }) async {
    try {
      await _ref.set({
        'safeSearch': safeSearch,
        'blockDoh': blockDoh,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo guardar: {0}', [e]))),
        );
      }
    }
  }

  Future<void> _applyPreset(BuildContext context, bool blockDoh) async {
    int age = 10;
    try {
      final child = await _childRef.get();
      final value = child.data()?['edad'];
      if (value is num) age = value.toInt();
    } catch (_) {}
    if (!context.mounted) return;

    final preset = AgePresets.forAge(age);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Recomendado: {0}', [preset.title])),
        content: SingleChildScrollView(
          child: Text(
            preset.isEmpty
                ? preset.description
                : tr('{0}\n\nSe añadirán {1} sitios y {2} apps a la lista negra (sin duplicar las que ya tengas). Podrás quitarlos cuando quieras.', [preset.description, preset.domains.length, preset.apps.length]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          if (!preset.isEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('Aplicar')),
            ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final rules = _childRef.collection('filter_rules');
    var added = 0;
    final problems = <String>[];

    Future<void> addAll(String category, List<String> values) async {
      if (values.isEmpty) return;
      try {
        final existing = await rules.where('category', isEqualTo: category).get();
        final have = existing.docs
            .map((d) => (d.data()['value'] ?? '').toString().toLowerCase())
            .toSet();
        final batch = FirebaseFirestore.instance.batch();
        for (final value in values) {
          if (have.contains(value.toLowerCase())) continue;
          batch.set(rules.doc(), {
            'type': 'block',
            'category': category,
            'value': value,
            'isEnabled': true,
            'createdAt': Timestamp.now(),
            'source': 'age_preset',
          });
          added++;
        }
        await batch.commit();
      } catch (e) {
        problems.add(category == 'app' ? 'apps' : tr('sitios web'));
      }
    }

    await addAll('url', preset.domains);
    await addAll('app', preset.apps);
    if (preset.safeSearch && context.mounted) {
      await _save(context, safeSearch: true, blockDoh: blockDoh);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(problems.isEmpty
            ? tr('Recomendaciones aplicadas: {0} reglas nuevas.', [added])
            : tr('Aplicado en parte ({0} reglas). Falta autorización para: {1}.', [added, problems.join(', ')])),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snapshot) {
        final unavailable = snapshot.hasError;
        final data = snapshot.data?.data();
        final safeSearch = data?['safeSearch'] == true;
        final blockDoh = data?['blockDoh'] != false;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            color: VestaTheme.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: VestaTheme.border),
          ),
          child: unavailable
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    tr('La protección web requiere autorización de filtrado de sitios.'),
                    style: TextStyle(color: VestaTheme.textSecondary, fontSize: 12),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            avatar: const Icon(Icons.travel_explore_rounded, size: 18),
                            label: Text(tr('Búsqueda segura')),
                            tooltip: tr('Fuerza SafeSearch en Google, Bing, DuckDuckGo y el modo restringido de YouTube'),
                            selected: safeSearch,
                            onSelected: (v) =>
                                _save(context, safeSearch: v, blockDoh: blockDoh),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilterChip(
                            avatar: const Icon(Icons.dns_rounded, size: 18),
                            label: Text(tr('Bloquear DNS cifrado')),
                            tooltip: tr('Impide saltarse el filtro con el "DNS seguro" del navegador'),
                            selected: blockDoh,
                            onSelected: (v) =>
                                _save(context, safeSearch: safeSearch, blockDoh: v),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _applyPreset(context, blockDoh),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(tr('Aplicar recomendaciones por edad')),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
