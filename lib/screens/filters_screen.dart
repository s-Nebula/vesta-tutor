import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vesta_app/theme/vesta_theme.dart';
import 'package:vesta_app/widgets/web_protection_card.dart';

import 'package:vesta_app/l10n/tr.dart';
class FiltersScreen extends StatefulWidget {
  final String childId;
  final String tutorId;

  const FiltersScreen({
    super.key,
    required this.childId,
    required this.tutorId,
  });

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  static const Color _wine = Color(0xFF792D43);
  static const Color _rose = Color(0xFFC15B68);
  // Text and surfaces follow the theme; _dark is the text colour of light fields.
  static Color get _ivory => VestaTheme.textPrimary;
  static const Color _dark = VestaTheme.dark;
  static Color get _surface => VestaTheme.surface;
  static const Color _muted = Color(0xFF927F85);

  final _valueController = TextEditingController();

  String _selectedType = 'block';
  String _selectedCategory = 'url';
  bool _isLoading = false;

  CollectionReference<Map<String, dynamic>> get _rules =>
      FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('filter_rules');

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRulesStream() {
    final category = _selectedType == 'block' ? _selectedCategory : 'url';

    return _rules
        .where('category', isEqualTo: category)
        .where('type', isEqualTo: _selectedType)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _addRule() async {
    final value = _valueController.text.trim().toLowerCase();
    if (value.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _rules.add({
        'type': _selectedType,
        'category': _selectedType == 'block' ? _selectedCategory : 'url',
        'value': value,
        'isEnabled': true,
        'createdAt': Timestamp.now(),
      });

      _valueController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Regla añadida correctamente'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al guardar: {0}', [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRule(String ruleId, bool isEnabled) async {
    try {
      await _rules.doc(ruleId).update({'isEnabled': isEnabled});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al actualizar: {0}', [e]))),
        );
      }
    }
  }

  Future<void> _deleteRule(String ruleId) async {
    try {
      await _rules.doc(ruleId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Regla eliminada'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al eliminar: {0}', [e]))),
        );
      }
    }
  }

  Future<void> _selectApps() async {
    final existingSnapshot =
        await _rules.where('category', isEqualTo: 'app').get();

    final existingRules = {
      for (final doc in existingSnapshot.docs)
        (doc.data()['value'] ?? '').toString(): doc,
    };

    final selected = <String>{
      for (final entry in existingRules.entries)
        if (entry.value.data()['isEnabled'] == true) entry.key,
    };

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 440,
                  height: 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_wine, _rose],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.apps_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr('Aplicaciones'),
                              style: TextStyle(
                                color: VestaTheme.textPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(
                              Icons.close_rounded,
                              color: VestaTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('{0} aplicaciones seleccionadas', [selected.length]),
                        style: TextStyle(
                          color: VestaTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('children')
                              .doc(widget.childId)
                              .collection('installed_apps')
                              .where('isInstalled', isEqualTo: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: _rose,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  tr('Error al cargar aplicaciones: {0}', [snapshot.error]),
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              );
                            }

                            final apps = snapshot.data?.docs.toList() ?? [];

                            apps.sort((a, b) {
                              final nameA =
                                  (a.data()['appName'] ?? '').toString();
                              final nameB =
                                  (b.data()['appName'] ?? '').toString();
                              return nameA.toLowerCase().compareTo(
                                    nameB.toLowerCase(),
                                  );
                            });

                            if (apps.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    tr('Todavía no hay aplicaciones disponibles.\n\nAbre Vesta Tracker en el dispositivo hijo y espera a que sincronice el catálogo.'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: VestaTheme.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: apps.length,
                              itemBuilder: (context, index) {
                                final data = apps[index].data();
                                final packageName =
                                    (data['packageName'] ?? apps[index].id)
                                        .toString();
                                final appName =
                                    (data['appName'] ?? packageName).toString();
                                final iconBase64 =
                                    (data['iconBase64'] ?? '').toString();

                                Widget appIcon = Icon(
                                  Icons.android_rounded,
                                  color: VestaTheme.textSecondary,
                                  size: 30,
                                );

                                if (iconBase64.isNotEmpty) {
                                  try {
                                    appIcon = Image.memory(
                                      base64Decode(iconBase64),
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.android_rounded,
                                        color: VestaTheme.textSecondary,
                                        size: 30,
                                      ),
                                    );
                                  } catch (_) {
                                    // Use the generic icon.
                                  }
                                }

                                final isSelected =
                                    selected.contains(packageName);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 7),
                                  decoration: BoxDecoration(
                                    color: VestaTheme.background,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: isSelected
                                          ? _rose.withValues(alpha: 0.65)
                                          : VestaTheme.border,
                                    ),
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          selected.add(packageName);
                                        } else {
                                          selected.remove(packageName);
                                        }
                                      });
                                    },
                                    secondary: appIcon,
                                    title: Text(
                                      appName,
                                      style: TextStyle(
                                        color: VestaTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      packageName,
                                      style: TextStyle(
                                        color: VestaTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    activeColor: _rose,
                                    checkColor: Colors.white,
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(color: VestaTheme.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(tr('Cancelar')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _gradientButton(
                              label: tr('Guardar selección'),
                              icon: Icons.check_rounded,
                              onPressed: () async {
                                Navigator.pop(dialogContext);

                                try {
                                  final batch =
                                      FirebaseFirestore.instance.batch();

                                  for (final entry in existingRules.entries) {
                                    final shouldEnable =
                                        selected.contains(entry.key);
                                    final currentlyEnabled =
                                        entry.value.data()['isEnabled'] == true;

                                    if (shouldEnable != currentlyEnabled) {
                                      batch.update(entry.value.reference, {
                                        'isEnabled': shouldEnable,
                                      });
                                    }
                                  }

                                  for (final packageName in selected) {
                                    if (!existingRules
                                        .containsKey(packageName)) {
                                      final reference = _rules.doc();
                                      batch.set(reference, {
                                        'type': 'block',
                                        'category': 'app',
                                        'value': packageName,
                                        'isEnabled': true,
                                        'createdAt': Timestamp.now(),
                                      });
                                    }
                                  }

                                  await batch.commit();

                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          tr('Aplicaciones actualizadas correctamente'),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(tr('Error al guardar: {0}', [e])),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: VestaTheme.screenGradient.colors,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
        // The whole screen scrolls as one page: with the header, the web
        // protection card and the form above, a list limited to the space
        // left below was only a few pixels tall on small phones.
        child: ListView(
          padding: const EdgeInsets.only(top: 20, bottom: 24),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_wine, _rose],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _rose.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Control de contenido'),
                        style: TextStyle(
                          color: _ivory,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        tr('Administra las restricciones del dispositivo'),
                        style: TextStyle(
                          color: Color(0xFFB9A8AD),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            WebProtectionCard(childId: widget.childId),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: VestaTheme.border),
              ),
              child: Row(
                children: [
                  _typeButton(tr('Lista negra'), 'block', Icons.block_rounded),
                  _typeButton(
                    tr('Lista blanca'),
                    'allow',
                    Icons.verified_user_rounded,
                  ),
                ],
              ),
            ),
            if (_selectedType == 'block') ...[
              const SizedBox(height: 18),
              Text(
                tr('CATEGORÍA DE BLOQUEO'),
                style: TextStyle(
                  color: VestaTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: _surface,
                style: TextStyle(color: _ivory),
                decoration: _inputDecoration(
                  label: tr('Tipo de bloqueo'),
                  icon: Icons.tune_rounded,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'url',
                    child: Text(tr('Dominio web')),
                  ),
                  DropdownMenuItem(
                    value: 'app',
                    child: Text(tr('Aplicación Android')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            if (_selectedType == 'block' && _selectedCategory == 'app')
              _gradientButton(
                label: tr('Elegir aplicaciones instaladas'),
                icon: Icons.apps_rounded,
                onPressed: _selectApps,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _valueController,
                      style: const TextStyle(
                        color: _dark,
                        fontSize: 14,
                      ),
                      decoration: _inputDecoration(
                        label: _selectedType == 'block'
                            ? tr('Ejemplo: sitio-web.com')
                            : tr('Ejemplo: educacion.com'),
                        icon: Icons.language_rounded,
                        light: true,
                      ),
                      onSubmitted: (_) => _addRule(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 54,
                    width: 54,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: _rose),
                          )
                        : _gradientButton(
                            icon: Icons.add_rounded,
                            onPressed: _addRule,
                            compact: true,
                          ),
                  ),
                ],
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Reglas configuradas'),
                    style: TextStyle(
                      color: _ivory,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _wine.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr('EN VIGOR'),
                    style: TextStyle(
                      color: Color(0xFFE9B8BD),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _getRulesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(color: _rose),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        tr('Error al cargar reglas: {0}', [snapshot.error]),
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final allRules = snapshot.data?.docs ?? [];

                  final rules = allRules.where((doc) {
                    final category = doc.data()['category'];

                    if (_selectedType == 'block') {
                      if (_selectedCategory == 'app') {
                        return category == 'app';
                      }
                      return category != 'app';
                    }
                    return true;
                  }).toList();

                  if (rules.isEmpty) {
                    return Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: VestaTheme.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: VestaTheme.textSecondary,
                              size: 38,
                            ),
                            SizedBox(height: 12),
                            Text(
                              tr('Sin reglas configuradas'),
                              style: TextStyle(
                                color: _ivory,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              tr('Añade una regla para comenzar a proteger el dispositivo.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    // Scrolls with the page (see the ListView above).
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: rules.length,
                    itemBuilder: (context, index) {
                      final doc = rules[index];
                      final rule = doc.data();
                      final enabled = rule['isEnabled'] ?? true;
                      final value = (rule['value'] ?? '').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: enabled
                                ? _rose.withValues(alpha: 0.24)
                                : VestaTheme.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: enabled
                                      ? [_wine, _rose]
                                      : [
                                          VestaTheme.burgundy,
                                          VestaTheme.wine,
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                _selectedType == 'allow'
                                    ? Icons.check_circle_outline_rounded
                                    : (_selectedCategory == 'app'
                                        ? Icons.android_rounded
                                        : Icons.language_rounded),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: enabled ? _ivory : VestaTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    enabled ? tr('Activa') : tr('Desactivada'),
                                    style: TextStyle(
                                      color: enabled ? _rose : _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: enabled,
                              activeThumbColor: _rose,
                              onChanged: (value) => _updateRule(doc.id, value),
                            ),
                            IconButton(
                              tooltip: tr('Eliminar regla'),
                              onPressed: () => _deleteRule(doc.id),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: VestaTheme.textSecondary,
                                size: 21,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String label, String type, IconData icon) {
    final selected = _selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
          decoration: BoxDecoration(
            gradient:
                selected ? const LinearGradient(colors: [_wine, _rose]) : null,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _rose.withValues(alpha: 0.22),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : _muted,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : _muted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    bool light = false,
  }) {
    final foreground = light ? VestaTheme.dark : _ivory;

    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(
        color: light ? _muted : VestaTheme.textSecondary,
        fontSize: 12,
      ),
      prefixIcon: Icon(icon, color: light ? _wine : _rose, size: 20),
      filled: true,
      fillColor: light ? VestaTheme.ivory : _surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: light ? VestaTheme.ivory : VestaTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _rose, width: 1.5),
      ),
      hintMaxLines: 1,
      labelStyle: TextStyle(color: foreground),
    );
  }

  Widget _gradientButton({
    String? label,
    IconData? icon,
    required VoidCallback onPressed,
    bool compact = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_wine, _rose],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _rose.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 16,
              vertical: compact ? 0 : 15,
            ),
            child: SizedBox(
              width: compact ? double.infinity : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) Icon(icon, color: Colors.white, size: 20),
                  if (label != null && icon != null) const SizedBox(width: 9),
                  if (label != null)
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
