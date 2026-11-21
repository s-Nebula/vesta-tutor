import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  static const Color _ivory = Color(0xFFF4EDEA);
  static const Color _dark = Color(0xFF211B20);
  static const Color _surface = Color(0xFF30232B);
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
          const SnackBar(content: Text('Regla añadida correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
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
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    }
  }

  Future<void> _deleteRule(String ruleId) async {
    try {
      await _rules.doc(ruleId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Regla eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
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
                          const Expanded(
                            child: Text(
                              'Aplicaciones',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selected.length} aplicaciones seleccionadas',
                        style: const TextStyle(
                          color: Color(0xFFD6B7A6),
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
                                  'Error al cargar aplicaciones: '
                                  '${snapshot.error}',
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
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text(
                                    'Todavía no hay aplicaciones disponibles.\n\n'
                                    'Abre Vesta Tracker en el dispositivo '
                                    'hijo y espera a que sincronice el catálogo.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
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

                                Widget appIcon = const Icon(
                                  Icons.android_rounded,
                                  color: Color(0xFFD6B7A6),
                                  size: 30,
                                );

                                if (iconBase64.isNotEmpty) {
                                  try {
                                    appIcon = Image.memory(
                                      base64Decode(iconBase64),
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.android_rounded,
                                        color: Color(0xFFD6B7A6),
                                        size: 30,
                                      ),
                                    );
                                  } catch (_) {
                                    // Se utiliza el icono genérico.
                                  }
                                }

                                final isSelected =
                                    selected.contains(packageName);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 7),
                                  decoration: BoxDecoration(
                                    color: _dark,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: isSelected
                                          ? _rose.withValues(alpha: 0.65)
                                          : Colors.white12,
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      packageName,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
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
                                side: const BorderSide(color: Colors.white24),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _gradientButton(
                              label: 'Guardar selección',
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
                                      const SnackBar(
                                        content: Text(
                                          'Aplicaciones actualizadas '
                                          'correctamente',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text('Error al guardar: $e'),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_dark, Color(0xFF30232B)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control de contenido',
                        style: TextStyle(
                          color: _ivory,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Administra las restricciones del dispositivo',
                        style: TextStyle(
                          color: Color(0xFFB9A8AD),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  _typeButton('Lista negra', 'block', Icons.block_rounded),
                  _typeButton(
                    'Lista blanca',
                    'allow',
                    Icons.verified_user_rounded,
                  ),
                ],
              ),
            ),
            if (_selectedType == 'block') ...[
              const SizedBox(height: 18),
              const Text(
                'CATEGORÍA DE BLOQUEO',
                style: TextStyle(
                  color: Color(0xFFD6B7A6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                dropdownColor: _surface,
                style: const TextStyle(color: _ivory),
                decoration: _inputDecoration(
                  label: 'Tipo de bloqueo',
                  icon: Icons.tune_rounded,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'url',
                    child: Text('Dominio web'),
                  ),
                  DropdownMenuItem(
                    value: 'app',
                    child: Text('Aplicación Android'),
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
                label: 'Elegir aplicaciones instaladas',
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
                            ? 'Ejemplo: sitio-web.com'
                            : 'Ejemplo: educacion.com',
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
                const Expanded(
                  child: Text(
                    'Reglas configuradas',
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
                  child: const Text(
                    'EN VIGOR',
                    style: TextStyle(
                      color: Color(0xFFE9B8BD),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _getRulesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _rose),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error al cargar reglas: ${snapshot.error}',
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
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: Color(0xFFD6B7A6),
                              size: 38,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Sin reglas configuradas',
                              style: TextStyle(
                                color: _ivory,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Añade una regla para comenzar a proteger '
                              'el dispositivo.',
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
                    padding: const EdgeInsets.only(bottom: 12),
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
                                : Colors.white10,
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
                                          Colors.grey.shade800,
                                          Colors.grey.shade700,
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
                                      color: enabled ? _ivory : Colors.white54,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    enabled ? 'Activa' : 'Desactivada',
                                    style: TextStyle(
                                      color: enabled ? _rose : _muted,
                                      fontSize: 10,
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
                              tooltip: 'Eliminar regla',
                              onPressed: () => _deleteRule(doc.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFD6B7A6),
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
                  fontSize: 10,
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
    final foreground = light ? _dark : _ivory;

    return InputDecoration(
      hintText: label,
      hintStyle: TextStyle(
        color: light ? _muted : Colors.white54,
        fontSize: 12,
      ),
      prefixIcon: Icon(icon, color: light ? _wine : _rose, size: 20),
      filled: true,
      fillColor: light ? _ivory : _surface,
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
          color: light ? _ivory : Colors.white10,
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
