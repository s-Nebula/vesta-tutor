import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vesta_app/services/child_profile_service.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Linking card: QR + code + copy + generate a new one.
///
/// The QR encodes `vesta://link?code=XXXXXXXXXX`, which Vesta Tracker reads with
/// the camera. The 10-character code can still be typed in.
class PairingCard extends StatefulWidget {
  final String childId;
  final String childName;
  final String pairingCode;

  /// Code expiry (24 h). Null on old profiles.
  final DateTime? expiresAt;

  const PairingCard({
    super.key,
    required this.childId,
    required this.childName,
    required this.pairingCode,
    this.expiresAt,
  });

  @override
  State<PairingCard> createState() => _PairingCardState();
}

class _PairingCardState extends State<PairingCard> {
  late String _code = widget.pairingCode;
  late DateTime? _expiresAt = widget.expiresAt;
  bool _regenerating = false;

  @override
  void didUpdateWidget(covariant PairingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The code arrives in real time from Firestore.
    if (widget.pairingCode != oldWidget.pairingCode) {
      _code = widget.pairingCode;
      _expiresAt = widget.expiresAt;
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Código copiado.'))),
    );
  }

  Future<void> _regenerate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('¿Generar un código nuevo?')),
        content: Text(
          tr('El código actual dejará de funcionar. Úsalo si crees que alguien más lo ha visto o si el anterior no funciona.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Generar')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _regenerating = true);
    try {
      final code = await ChildProfileService.regeneratePairingCode(
        widget.childId,
      );
      if (mounted) {
        setState(() {
          _code = code;
          _expiresAt = DateTime.now().add(const Duration(hours: 24));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo generar el código: {0}', [e]))),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired =
        _expiresAt != null && DateTime.now().isAfter(_expiresAt!);
    final hasCode = RegExp(r'^[A-F0-9]{10}$').hasMatch(_code) && !expired;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VestaTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VestaTheme.beige.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.childName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VestaTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr('Abre Vesta Tracker en su teléfono y escanea este código'),
            textAlign: TextAlign.center,
            style: TextStyle(color: VestaTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (hasCode)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: QrImageView(
                  data: ChildProfileService.qrPayload(_code),
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: VestaTheme.wine,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: VestaTheme.dark,
                  ),
                  semanticsLabel: 'Código QR de vinculación',
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                expired
                    ? tr('Este código caducó. Genera uno nuevo para vincular.')
                    : tr('Código no disponible. Genera uno nuevo.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: VestaTheme.textSecondary),
              ),
            ),
          if (hasCode) ...[
            const SizedBox(height: 16),
            Text(
              tr('O introduce el código a mano'),
              textAlign: TextAlign.center,
              style: TextStyle(color: VestaTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            SelectableText(
              '${_code.substring(0, 5)} ${_code.substring(5)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VestaTheme.beige,
                fontSize: 26,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (hasCode && _expiresAt != null) ...[
            const SizedBox(height: 4),
            Text(
              tr('Caduca el {0}/{1} a las {2}:{3}', [_expiresAt!.day.toString().padLeft(2, '0'), _expiresAt!.month.toString().padLeft(2, '0'), _expiresAt!.hour.toString().padLeft(2, '0'), _expiresAt!.minute.toString().padLeft(2, '0')]),
              textAlign: TextAlign.center,
              style: TextStyle(color: VestaTheme.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              if (hasCode)
                TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(tr('Copiar')),
                ),
              TextButton.icon(
                onPressed: _regenerating ? null : _regenerate,
                icon: _regenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(tr('Código nuevo')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the linking card in a bottom sheet.
Future<void> showPairingSheet(
  BuildContext context, {
  required String childId,
  required String childName,
  required String pairingCode,
  DateTime? expiresAt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VestaTheme.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: VestaTheme.beige.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            PairingCard(
              childId: childId,
              childName: childName,
              pairingCode: pairingCode,
              expiresAt: expiresAt,
            ),
            const SizedBox(height: 12),
            Text(
              tr('La vinculación se detecta automáticamente.'),
              style: TextStyle(color: VestaTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Expiry stored in the profile (`pairingCodeExpiresAt`).
DateTime? pairingExpiryOf(Map<String, dynamic> child) {
  final value = child['pairingCodeExpiresAt'];
  return value is Timestamp ? value.toDate() : null;
}
