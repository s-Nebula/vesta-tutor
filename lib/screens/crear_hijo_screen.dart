import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/database_service.dart';

class CrearHijoScreen extends StatefulWidget {
  const CrearHijoScreen({super.key});

  @override
  State<CrearHijoScreen> createState() => _CrearHijoScreenState();
}

class _CrearHijoScreenState extends State<CrearHijoScreen> {
  static const Color _wine = Color(0xFF792D43);
  static const Color _rose = Color(0xFFC15B68);
  static const Color _ivory = Color(0xFFF4EDEA);
  static const Color _dark = Color(0xFF211B20);
  static const Color _muted = Color(0xFF8D7D82);

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _edadController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  bool _cargando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _edadController.dispose();
    super.dispose();
  }

  Future<void> _crearPerfil() async {
    final nombre = _nombreController.text.trim();
    final edad = int.tryParse(_edadController.text.trim());

    if (nombre.isEmpty || edad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un nombre y una edad válida.'),
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final result = await _dbService.crearNuevoHijo(
        nombre,
        edad,
        Colors.blue.toARGB32(),
      );

      final pairingCode = result['pairingCode'] as String;

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _ivory,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF559B79)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Perfil creado',
                  style: TextStyle(
                    color: _dark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Introduce este código en Vesta Tracker para vincular el dispositivo:',
                style: TextStyle(color: _dark, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9DCE0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _rose.withValues(alpha: 0.35)),
                ),
                child: SelectableText(
                  pairingCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _wine,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'El código es de un solo uso. Guárdalo antes de continuar.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pairingCode));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código copiado.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar código'),
              style: TextButton.styleFrom(foregroundColor: _wine),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _wine,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (mounted) context.go('/');
    } catch (e) {
      debugPrint('Error al crear perfil: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear el perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        backgroundColor: _dark,
        appBar: AppBar(
          backgroundColor: _dark,
          foregroundColor: _ivory,
          elevation: 0,
          title: const Text(
            'Registrar nuevo hijo',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/'),
          ),
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
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
                  const Text(
                    'Crear perfil del menor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ivory,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Registra sus datos para generar el código de vinculación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ivory.withValues(alpha: 0.72),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 27),
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
                        const Text(
                          'Información del perfil',
                          style: TextStyle(
                            color: _dark,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Completa los datos del menor.',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 23),
                        _buildField(
                          controller: _nombreController,
                          label: 'Nombre del menor',
                          hint: 'Introduce su nombre',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 17),
                        _buildField(
                          controller: _edadController,
                          label: 'Edad',
                          hint: 'Introduce su edad',
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9DCE0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: _wine,
                              ),
                              SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  'Se asignará un identificador azul al perfil.',
                                  style: TextStyle(
                                    color: _wine,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 27),
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
                              onPressed: _cargando ? null : _crearPerfil,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              child: _cargando
                                  ? const SizedBox(
                                      width: 23,
                                      height: 23,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.qr_code_rounded),
                                        SizedBox(width: 10),
                                        Text(
                                          'Generar código y registrar',
                                          style: TextStyle(
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
                            onPressed: () => context.go('/'),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Cancelar'),
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
                        'VESTA · Protección y tranquilidad',
                        style: TextStyle(
                          color: _ivory.withValues(alpha: 0.65),
                          fontSize: 11,
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
      ),
    );
  }
}
