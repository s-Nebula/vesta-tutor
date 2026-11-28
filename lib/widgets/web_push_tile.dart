import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:vesta_app/services/notification_service.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';

/// Web panel, Settings: turn on push notifications in this browser.
/// The permission is asked only when the guardian taps the button.
class WebPushTile extends StatefulWidget {
  const WebPushTile({super.key});

  /// Shown only on the web, when web push is configured.
  static bool get visible =>
      kIsWeb && NotificationService.instance.webPushAvailable;

  @override
  State<WebPushTile> createState() => _WebPushTileState();
}

class _WebPushTileState extends State<WebPushTile> {
  AuthorizationStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.webPermission().then((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    AuthorizationStatus status;
    try {
      status = await NotificationService.instance.enableWebPush();
    } catch (e) {
      status = AuthorizationStatus.denied;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudieron activar: {0}', [e]))),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final granted = status == AuthorizationStatus.authorized;
    final denied = status == AuthorizationStatus.denied;

    return ListTile(
      leading: Icon(
        granted
            ? Icons.notifications_active_rounded
            : Icons.notifications_off_outlined,
        color: granted ? VestaTheme.rose : null,
      ),
      title: Text(tr('Notificaciones en este navegador')),
      subtitle: Text(
        granted
            ? tr('Activadas. Recibirás las alertas aunque la página esté cerrada, mientras el navegador esté abierto.')
            : denied
                ? tr('Bloqueadas. Permítelas en los ajustes del sitio de tu navegador (icono del candado junto a la dirección).')
                : tr('Recibe las alertas en este ordenador o móvil. En iPhone, primero añade Vesta a la pantalla de inicio.'),
      ),
      trailing: granted || denied || status == null
          ? null
          : _busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: VestaTheme.wine,
                  ),
                  onPressed: _enable,
                  child: Text(tr('Activar')),
                ),
    );
  }
}
