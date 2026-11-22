import 'package:flutter/material.dart';
import 'package:vesta_app/widgets/privacy_access_gate.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vesta_app/services/api_client.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
class PrivacyConsentScreen extends StatefulWidget {
  final Future<void> Function()? onConsentChanged;

  const PrivacyConsentScreen({
    super.key,
    this.onConsentChanged,
  });

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  late Future<Map<String, dynamic>> _statusFuture;

  static Map<String, String> get _purposes => {
    'location': tr('Ubicación e historial'),
    'device_status': tr('Estado del dispositivo'),
    'usage_stats': tr('Estadísticas de uso de aplicaciones'),
    'app_filtering': tr('Filtrado de aplicaciones'),
    'domain_filtering': tr('Filtrado de dominios'),
    'alerts': tr('Alertas y eventos'),
  };

  /// Legal documents shown in the app. English versions are a courtesy
  /// translation; the Spanish text prevails.
  static Map<String, String> get _documents => isEnglish
      ? {
          'Terms and Conditions': 'assets/legal/en/terms_and_conditions.txt',
          'Privacy Policy': 'assets/legal/en/privacy_policy.txt',
          'User Guide': 'assets/legal/en/user_guide.txt',
        }
      : {
          'Términos y condiciones': 'assets/legal/terminos_y_condiciones.txt',
          'Política de privacidad': 'assets/legal/politica_privacidad.txt',
          'Guía de usuario': 'assets/legal/guia_usuario.txt',
        };

  final Map<String, bool> _selectedPurposes = {
    for (final key in _purposes.keys) key: false,
  };

  bool _acceptTerms = false;
  bool _acknowledgePrivacy = false;
  bool _guardianDeclaration = false;
  String? _minorParticipation;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<Map<String, dynamic>> _loadStatus() {
    return VestaApiClient.get('/api/privacy/status');
  }

  Future<void> _refresh() async {
    final future = _loadStatus();
    setState(() {
      _statusFuture = future;
    });
    await future;
  }

  Future<void> _showDocument(String title, String asset) async {
    try {
      final content = await rootBundle.loadString(asset);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 600,
            height: MediaQuery.of(context).size.height * 0.65,
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('Cerrar')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('No se pudo abrir el documento: {0}', [error]))),
      );
    }
  }

  Future<void> _submitConsent({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    if (_submitting) return;

    if (!_acceptTerms ||
        !_acknowledgePrivacy ||
        !_guardianDeclaration ||
        _minorParticipation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Debes completar todas las confirmaciones obligatorias.'),
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await VestaApiClient.post(
        '/api/privacy/consent',
        body: {
          'termsVersion': termsVersion,
          'privacyVersion': privacyVersion,
          'acceptTerms': _acceptTerms,
          'acknowledgePrivacy': _acknowledgePrivacy,
          'guardianDeclaration': _guardianDeclaration,
          'minorParticipation': _minorParticipation,
          'purposes': Map<String, bool>.from(_selectedPurposes),
        },
      );

      PrivacyAccessGate.invalidate();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Consentimiento enviado. Verificando estado...')),
        ),
      );

      if (widget.onConsentChanged != null) {
        await widget.onConsentChanged!();
      } else {
        final statusFuture = _loadStatus();
        setState(() {
          _statusFuture = statusFuture;
        });
        final refreshedStatus = await statusFuture;
        if (mounted && refreshedStatus['valid'] == true) {
          context.go('/');
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('No se pudo registrar el consentimiento: {0}', [error])),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _revoke(String purpose) async {
    final isAll = purpose == 'all';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isAll ? tr('Revocar todas las autorizaciones') : tr('Revocar autorización'),
        ),
        content: Text(
          isAll
              ? tr('¿Quieres revocar todas las autorizaciones de privacidad?')
              : tr('¿Quieres revocar la autorización para {0}?', [_purposes[purpose] ?? purpose]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Revocar')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await VestaApiClient.post(
        '/api/privacy/revoke',
        body: {'purpose': purpose},
      );

      PrivacyAccessGate.invalidate();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Solicitud de revocación procesada.')),
        ),
      );

      await _refresh();
      if (mounted && widget.onConsentChanged != null) {
        await widget.onConsentChanged!();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('No se pudo revocar la autorización: {0}', [error]))),
      );
    }
  }

  Widget _buildDocuments() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Documentos de Vesta'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (isEnglish)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Courtesy translation. The Spanish version is the official text and prevails in case of any discrepancy.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ..._documents.entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(entry.key),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _showDocument(entry.key, entry.value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentForm(
    String termsVersion,
    String privacyVersion,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          tr('Autorizaciones y finalidades'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          tr('Cada finalidad es independiente y opcional. Deja desmarcadas aquellas que no autorizas.'),
        ),
        const SizedBox(height: 8),
        ..._purposes.entries.map(
          (entry) => Card(
            child: CheckboxListTile(
              value: _selectedPurposes[entry.key] ?? false,
              title: Text(entry.value),
              subtitle: Text(tr('Autorización independiente')),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _selectedPurposes[entry.key] = value ?? false;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr('Participación del menor'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        RadioListTile<String>(
          value: 'informed',
          groupValue: _minorParticipation,
          title: Text(tr('El menor fue informado')),
          onChanged: (value) => setState(
            () => _minorParticipation = value,
          ),
        ),
        RadioListTile<String>(
          value: 'heard',
          groupValue: _minorParticipation,
          title: Text(tr('Se escuchó la opinión del menor')),
          onChanged: (value) => setState(
            () => _minorParticipation = value,
          ),
        ),
        RadioListTile<String>(
          value: 'not_applicable',
          groupValue: _minorParticipation,
          title: Text(tr('No aplica')),
          onChanged: (value) => setState(
            () => _minorParticipation = value,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                CheckboxListTile(
                  value: _acceptTerms,
                  title: Text(tr('Acepto los términos y condiciones.')),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => setState(
                    () => _acceptTerms = value ?? false,
                  ),
                ),
                CheckboxListTile(
                  value: _acknowledgePrivacy,
                  title: Text(
                    tr('Confirmo que he leído la política de privacidad.'),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => setState(
                    () => _acknowledgePrivacy = value ?? false,
                  ),
                ),
                CheckboxListTile(
                  value: _guardianDeclaration,
                  title: Text(
                    tr('Declaro que soy tutor, representante legal o persona autorizada y que actúo bajo mi responsabilidad.'),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => setState(
                    () => _guardianDeclaration = value ?? false,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitting ||
                    termsVersion.toLowerCase().contains('draft') ||
                    privacyVersion.toLowerCase().contains('draft')
                ? null
                : () => _submitConsent(
                      termsVersion: termsVersion,
                      privacyVersion: privacyVersion,
                    ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              _submitting ? tr('Enviando...') : tr('Registrar consentimiento'),
            ),
          ),
        ),
      ],
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = context.canPop();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: canGoBack ? tr('Volver') : tr('Cerrar sesión'),
          onPressed: _handleBack,
          icon: Icon(
            canGoBack ? Icons.arrow_back : Icons.logout,
          ),
        ),
        title: Text(tr('Privacidad y autorizaciones')),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      tr('No se pudo consultar el estado de privacidad.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _statusFuture = _loadStatus();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(tr('Reintentar')),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final exists = data['exists'] == true;
          final valid = data['valid'] == true;

          final rawConsent = data['consent'];
          final consent = rawConsent is Map
              ? Map<String, dynamic>.from(rawConsent)
              : <String, dynamic>{};

          final rawPurposes = consent['purposes'];
          final granted = rawPurposes is Map
              ? Map<String, dynamic>.from(rawPurposes)
              : <String, dynamic>{};

          final versionsRaw = data['currentVersions'];
          final versions = versionsRaw is Map
              ? Map<String, dynamic>.from(versionsRaw)
              : <String, dynamic>{};

          final termsVersion =
              versions['termsVersion']?.toString() ?? tr('No disponible');
          final privacyVersion =
              versions['privacyVersion']?.toString() ?? tr('No disponible');

          final isDraft = termsVersion.toLowerCase().contains('draft') ||
              privacyVersion.toLowerCase().contains('draft');

          final status = consent['status']?.toString() ?? tr('sin registro');

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr('Estado del consentimiento'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          exists
                              ? tr('Registro: {0}', [status])
                              : tr('Todavía no existe un registro de consentimiento.'),
                        ),
                        const SizedBox(height: 6),
                        Text(tr('Consentimiento válido: {0}', [valid ? tr('Sí') : tr('No')])),
                        const SizedBox(height: 6),
                        Text(tr('Términos: {0}', [termsVersion])),
                        Text(tr('Privacidad: {0}', [privacyVersion])),
                      ],
                    ),
                  ),
                ),
                if (isDraft)
                  Card(
                    color: VestaTheme.surfaceLight,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        tr('Los documentos legales todavía están en versión borrador. La aceptación está deshabilitada hasta que se aprueben y configuren las versiones definitivas en el servidor.'),
                      ),
                    ),
                  ),
                _buildDocuments(),
                if (!valid) ...[
                  _buildConsentForm(termsVersion, privacyVersion),
                ] else ...[
                  const SizedBox(height: 16),
                  Text(
                    tr('Finalidades autorizadas'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ..._purposes.entries.map((entry) {
                    final enabled = granted[entry.key] == true;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          enabled
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          color: enabled ? Colors.green : null,
                        ),
                        title: Text(entry.value),
                        subtitle: Text(
                          enabled ? tr('Autorizada') : tr('No autorizada'),
                        ),
                        trailing: enabled
                            ? IconButton(
                                tooltip: tr('Revocar autorización'),
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _revoke(entry.key),
                              )
                            : null,
                      ),
                    );
                  }),
                  if (exists && status != 'revoked') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _revoke('all'),
                      icon: const Icon(Icons.block),
                      label: Text(tr('Revocar todas las autorizaciones')),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      tr('La autorización efectiva de un menor también depende del consentimiento de todos sus tutores asociados y de que tenga un dispositivo correctamente vinculado. La revocación se aplica según las reglas del servicio.'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(tr('Actualizar estado')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
