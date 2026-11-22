import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vesta_app/services/auth_service.dart';
import 'package:vesta_app/theme/vesta_theme.dart';
import 'package:vesta_app/theme_notifier.dart';

import 'package:vesta_app/l10n/tr.dart';
import 'package:vesta_app/services/notification_service.dart';
/// Guardian settings: appearance, language, notifications, privacy and account.
///
/// Notification preferences are stored in `users/{uid}`
/// (`notificationPrefs`) and the server applies them when sending pushes.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<void> _setPref(BuildContext context, String key, Object value) async {
    try {
      await _userRef?.set({
        'notificationPrefs': {key: value},
      }, SetOptions(merge: true));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo guardar: {0}', [e]))),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('¿Cerrar sesión?')),
        content: Text(
          tr('Dejarás de recibir alertas en este teléfono hasta que vuelvas a iniciar sesión.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Cerrar sesión')),
          ),
        ],
      ),
    );
    if (confirm == true) await AuthService().signOut();
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Text(
          title,
          style: TextStyle(
            color: VestaTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final language = context.watch<LanguageNotifier>();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(title: Text(tr('Ajustes'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _section(tr('APARIENCIA')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(tr('Oscuro')),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(tr('Claro')),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(tr('Sistema')),
                    icon: Icon(Icons.settings_suggest_rounded),
                  ),
                ],
                selected: {theme.themeMode},
                onSelectionChanged: (value) => theme.setTheme(value.first),
              ),
            ),
          ),
          _section(tr('IDIOMA')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'system',
                    label: Text(tr('Sistema')),
                    icon: const Icon(Icons.phone_android_rounded),
                  ),
                  const ButtonSegment(value: 'es', label: Text('Español')),
                  const ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {language.choice},
                onSelectionChanged: (value) {
                  language.setChoice(value.first);
                  NotificationService.instance.syncLanguage();
                },
              ),
            ),
          ),
          _section(tr('NOTIFICACIONES')),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userRef?.snapshots(),
            builder: (context, snapshot) {
              final prefs = (snapshot.data?.data()?['notificationPrefs'] as Map?) ?? {};
              final onlyCritical = prefs['instant'] == 'critical';
              final weekly = prefs['weeklySummary'] != false;

              return Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_rounded),
                      title: Text(tr('Solo alertas críticas al instante')),
                      subtitle: Text(
                        tr('Los avisos menores (batería, zonas, tiempo agotado) se quedan en la app y en el resumen semanal. El SOS siempre llega al instante.'),
                      ),
                      value: onlyCritical,
                      onChanged: (value) =>
                          _setPref(context, 'instant', value ? 'critical' : 'all'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.insights_rounded),
                      title: Text(tr('Resumen semanal')),
                      subtitle: Text(
                        tr('Cada domingo por la tarde: tiempo de pantalla, apps más usadas y alertas de la semana.'),
                      ),
                      value: weekly,
                      onChanged: (value) => _setPref(context, 'weeklySummary', value),
                    ),
                  ],
                ),
              );
            },
          ),
          _section(tr('PRIVACIDAD')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(tr('Privacidad y autorizaciones')),
              subtitle: Text(tr('Consentimientos y finalidades autorizadas')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/privacy'),
            ),
          ),
          _section(tr('CUENTA')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_rounded),
                  title: Text(user?.displayName ?? tr('Cuenta de tutor')),
                  subtitle: Text(user?.email ?? ''),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: VestaTheme.rose),
                  title: Text(tr('Cerrar sesión')),
                  onTap: () => _signOut(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: VestaTheme.danger),
                  title: Text(
                    tr('Eliminar cuenta'),
                    style: const TextStyle(color: VestaTheme.danger),
                  ),
                  subtitle: Text(tr('Borra tu cuenta y tus datos de forma definitiva')),
                  onTap: () => context.push('/delete-account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
