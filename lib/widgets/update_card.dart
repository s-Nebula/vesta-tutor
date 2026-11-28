import 'package:flutter/material.dart';
import 'package:vesta_app/services/app_updater.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';

/// "Updates" card in Settings. Only in the APK from vestasecurity.date:
/// in the Google Play build, Play handles the updates and nothing is shown.
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key, this.header});

  /// Section title, shown only when the card is.
  final Widget? header;

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> with WidgetsBindingObserver {
  UpdateStatus? _status;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Android's "install unknown apps" screen.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await AppUpdater.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final status = await AppUpdater.checkNow();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });
    if (status.lastError == null && !status.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Ya tienes la última versión.'))),
      );
    }
  }

  String _subtitle(UpdateStatus s) {
    if (_checking) return tr('Buscando actualizaciones…');
    if (s.lastError != null) {
      return tr('No se pudo actualizar: {0}', [s.lastError!]);
    }
    if (s.available) {
      return s.canInstall
          ? tr('Versión {0} descargada; instalando.', [s.availableVersionName ?? ''])
          : tr('Versión {0} disponible.', [s.availableVersionName ?? '']);
    }
    return tr('Se actualiza sola cuando publicamos una versión nueva.');
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null || !s.supported) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: Text(tr('Versión {0}', [s.currentVersionName ?? ''])),
                subtitle: Text(_subtitle(s)),
              ),
              if (!s.canInstall) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined, color: VestaTheme.rose),
                  title: Text(tr('Permitir actualizaciones automáticas')),
                  subtitle: Text(
                    tr('Android pide que autorices una vez a Vesta para instalar sus propias actualizaciones.'),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: AppUpdater.openInstallSettings,
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: _checking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                title: Text(tr('Buscar actualizaciones')),
                onTap: _checking ? null : _check,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
