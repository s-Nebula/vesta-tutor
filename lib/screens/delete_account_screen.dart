import 'package:flutter/material.dart';
import 'package:vesta_app/l10n/tr.dart';
import 'package:vesta_app/services/auth_service.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

/// Deletes the guardian's account and data (Google Play requirement).
/// Explains what is deleted, asks for confirmation and a fresh sign-in.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _auth = AuthService();
  final _password = TextEditingController();
  bool _understood = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final deleted = await _auth.deleteAccount(
        password: _auth.usesPassword ? _password.text : null,
      );
      if (!mounted) return;
      if (!deleted) {
        setState(() => _busy = false);
        return;
      }
      // Signing out sends the router back to the login screen.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Tu cuenta y tus datos se eliminaron.'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _point(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 10),
              child: Icon(Icons.remove_circle_outline_rounded,
                  size: 18, color: VestaTheme.danger),
            ),
            Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final usesPassword = _auth.usesPassword;
    final canDelete =
        _understood && !_busy && (!usesPassword || _password.text.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Eliminar cuenta'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr('Esta acción no se puede deshacer.'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _point(tr('Se eliminan tu cuenta, tu correo y tus preferencias.')),
          _point(tr('Se eliminan los perfiles de los que eres el único tutor, con su ubicación, alertas, informes, reglas, zonas y peticiones.')),
          _point(tr('Los teléfonos vinculados a esos perfiles quedan desvinculados y Vesta Tracker deja de enviar datos.')),
          _point(tr('En los perfiles que compartes con otro tutor solo se quita tu acceso; el otro tutor los conserva.')),
          _point(tr('Se eliminan tus consentimientos. Solo queda un registro anónimo de que la eliminación se hizo.')),
          const SizedBox(height: 8),
          if (usesPassword) ...[
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tr('Contraseña'),
                helperText: tr('Por seguridad, confirma tu contraseña.'),
              ),
            ),
          ] else
            Text(
              tr('Por seguridad, te pediremos que vuelvas a iniciar sesión.'),
              style: TextStyle(color: VestaTheme.textSecondary),
            ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _understood,
            onChanged: _busy ? null : (v) => setState(() => _understood = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr('Entiendo que se eliminarán mi cuenta y mis datos.')),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: VestaTheme.danger)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: VestaTheme.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: canDelete ? _delete : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.delete_forever_rounded),
            label: Text(tr('Eliminar cuenta definitivamente')),
          ),
          const SizedBox(height: 20),
          Text(
            tr('También puedes pedir la eliminación sin la app en vestasecurity.date/eliminar-cuenta.'),
            style: TextStyle(color: VestaTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
