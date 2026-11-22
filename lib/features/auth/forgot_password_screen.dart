import 'package:flutter/material.dart';
import 'package:vesta_app/services/auth_service.dart';

import 'package:vesta_app/l10n/tr.dart';
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  final authService = AuthService();

  bool _isLoading = false;

  static const Color _wine = Color(0xFF792D43);
  static const Color _rose = Color(0xFFC15B68);
  static const Color _dark = Color(0xFF211B20);
  static const Color _ivory = Color(0xFFF4EDEA);
  static const Color _muted = Color(0xFF8B7D82);

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage(tr('Introduce un correo electrónico válido.'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await authService.resetPassword(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Se ha enviado un correo de recuperación.')),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_dark, Color(0xFF351D29), _wine],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        tooltip: tr('Volver'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_rose, _wine],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: _rose.withValues(alpha: 0.35),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      tr('Recuperar contraseña'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      tr('Recupera el acceso a tu cuenta VESTA'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: _ivory,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tr('Restablecer acceso'),
                            style: TextStyle(
                              color: _dark,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            tr('Introduce el correo electrónico asociado a tu cuenta. Te enviaremos las instrucciones para restablecer tu contraseña.'),
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Text(
                            tr('Correo electrónico'),
                            style: TextStyle(
                              color: _dark,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: _dark,
                              fontSize: 13,
                            ),
                            cursorColor: _wine,
                            decoration: InputDecoration(
                              hintText: 'nombre@ejemplo.com',
                              hintStyle: const TextStyle(
                                color: Color(0xFFB0A3A7),
                                fontSize: 12,
                              ),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: _wine,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8DDE0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8DDE0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                  color: _rose,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_wine, _rose],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _wine.withValues(alpha: 0.25),
                                    blurRadius: 13,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _sendResetEmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: _wine.withValues(
                                    alpha: 0.55,
                                  ),
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            tr('Enviar instrucciones'),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      tr('VESTA · Seguridad y tranquilidad'),
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
