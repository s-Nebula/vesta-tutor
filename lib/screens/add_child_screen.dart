import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/child_profile_service.dart';
import '../services/database_service.dart';
import '../widgets/pairing_card.dart';

import 'package:vesta_app/l10n/tr.dart';
class AddChildScreen extends StatefulWidget {
  final Map<String, dynamic>? childData;

  const AddChildScreen({super.key, this.childData});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  static const Color _wine = Color(0xFF792D43);
  static const Color _rose = Color(0xFFC15B68);
  static const Color _ivory = Color(0xFFF4EDEA);
  static const Color _dark = Color(0xFF211B20);
  static const Color _muted = Color(0xFF8D7D82);

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingChildId;

  final List<Color> _avatarColors = [
    Color(0xFF537FCB),
    Color(0xFFC15B68),
    Color(0xFF559B79),
    Color(0xFFE39A52),
    Color(0xFF9670C4),
  ];

  int _selectedColorIndex = 0;

  @override
  void initState() {
    super.initState();

    final data = widget.childData;
    final childId = data?['childId'];

    if (data != null && childId is String && childId.isNotEmpty) {
      _isEditing = true;
      _editingChildId = childId;
      _nameController.text = data['nombre']?.toString() ?? '';
      _ageController.text = data['edad']?.toString() ?? '';

      final color = data['color'];
      if (color is int) {
        final index =
            _avatarColors.indexWhere((c) => c.toARGB32() == color);
        if (index >= 0) {
          _selectedColorIndex = index;
        } else {
          // A colour that is no longer in the palette: kept as an option.
          _avatarColors.add(Color(color));
          _selectedColorIndex = _avatarColors.length - 1;
        }
      }
    }
  }

  Future<void> _updateChild(String nombre, int edad) async {
    final childId = _editingChildId!;
    final original = widget.childData!;
    final color = _avatarColors[_selectedColorIndex].toARGB32();

    setState(() => _isLoading = true);

    try {
      await ChildProfileService.update(
        childId,
        nombre: nombre != original['nombre'] ? nombre : null,
        edad: edad != original['edad'] ? edad : null,
        color: color != original['color'] ? color : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Perfil actualizado.'))),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo actualizar el perfil: {0}', [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChild() async {
    final nombre = _nameController.text.trim();
    final edad = int.tryParse(_ageController.text.trim());

    if (nombre.isEmpty || nombre.length > 80 || edad == null || edad < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Introduce un nombre (máx. 80) y una edad válida.')),
        ),
      );
      return;
    }

    if (_isEditing) {
      await _updateChild(nombre, edad);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _dbService.crearNuevoHijo(
        nombre,
        edad,
        _avatarColors[_selectedColorIndex].toARGB32(),
      );

      final pairingCode = result['pairingCode'] as String;
      final childId = result['childId'] as String;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Perfil creado.'))),
      );

      await showPairingSheet(
        context,
        childId: childId,
        childName: nombre,
        pairingCode: pairingCode,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      if (mounted) context.go('/');
    } catch (e) {
      debugPrint('Error al crear perfil: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo crear el perfil: {0}', [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: _dark,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _wine),
        filled: true,
        fillColor: const Color(0xFFF8F4F2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        labelStyle: const TextStyle(color: _muted),
        hintStyle: const TextStyle(color: Color(0xFFB5A8AB)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE9DFE0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: _rose, width: 1.7),
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 17,
      runSpacing: 14,
      children: List.generate(_avatarColors.length, (index) {
        final color = _avatarColors[index];
        final selected = _selectedColorIndex == index;

        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _dark : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.48 : 0.18),
                  blurRadius: selected ? 15 : 7,
                  spreadRadius: selected ? 2 : 0,
                ),
              ],
            ),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 25,
                  )
                : null,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? tr('Editar perfil') : tr('Nuevo menor');

    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: _ivory,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF211B20),
              Color(0xFF421827),
              Color(0xFF30232B),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_wine, _rose],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _rose.withValues(alpha: 0.38),
                          blurRadius: 25,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.child_care_rounded,
                      color: Colors.white,
                      size: 39,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _isEditing ? tr('Actualiza la información') : tr('Añadir dispositivo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ivory,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isEditing
                      ? tr('Información del perfil del menor')
                      : tr('Crea un perfil para comenzar la vinculación con Vesta Tracker.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ivory.withValues(alpha: 0.72),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _ivory,
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Información del perfil'),
                        style: TextStyle(
                          color: _dark,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        tr('Completa los datos para identificar el dispositivo.'),
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 23),
                      _buildField(
                        controller: _nameController,
                        label: tr('Nombre del menor'),
                        hint: tr('Introduce su nombre'),
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 17),
                      _buildField(
                        controller: _ageController,
                        label: tr('Edad'),
                        hint: tr('Introduce su edad'),
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 27),
                      Text(
                        tr('Color identificador'),
                        style: TextStyle(
                          color: _dark,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('Selecciona un color para reconocer este perfil.'),
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildColorSelector(),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_wine, _rose],
                            ),
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: [
                              BoxShadow(
                                color: _rose.withValues(alpha: 0.32),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveChild,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_outline),
                                      const SizedBox(width: 10),
                                      Text(
                                        _isEditing
                                            ? tr('Actualizar información')
                                            : tr('Registrar menor'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton.icon(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/');
                            }
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: Text(tr('Cancelar')),
                          style: TextButton.styleFrom(
                            foregroundColor: _wine,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 15,
                      color: _ivory.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tr('VESTA · Protección y tranquilidad'),
                      style: TextStyle(
                        color: _ivory.withValues(alpha: 0.65),
                        fontSize: 12,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
