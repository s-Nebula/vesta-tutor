import 'package:vesta_app/services/api_client.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Profile operations only the backend can perform
/// (Firestore rules prevent writing `children/{id}` from the client).
class ChildProfileService {
  ChildProfileService._();

  static String _path(String childId) =>
      '/api/children/${Uri.encodeComponent(childId)}';

  static Future<void> update(
    String childId, {
    String? nombre,
    int? edad,
    int? color,
  }) async {
    final body = <String, dynamic>{
      if (nombre != null) 'nombre': nombre.trim(),
      if (edad != null) 'edad': edad,
      if (color != null) 'color': color,
    };

    if (body.isEmpty) return;

    await VestaApiClient.patch(_path(childId), body: body);
  }

  /// Generates a new code and invalidates the previous one.
  static Future<String> regeneratePairingCode(String childId) async {
    final result = await VestaApiClient.post('${_path(childId)}/pairing-code');
    final code = result['pairingCode'];
    if (code is! String) {
      throw VestaApiException(tr('El servidor no devolvió un código.'));
    }
    return code;
  }

  /// Unlinks the device and returns the new linking code.
  static Future<String> unlink(String childId) async {
    final result = await VestaApiClient.post('${_path(childId)}/unlink');
    return result['pairingCode'] as String? ?? '';
  }

  /// Deletes the profile. If other guardians share it, only this guardian
  /// leaves it and it stays with them. Returns true if it was deleted.
  static Future<bool> delete(String childId) async {
    final result = await VestaApiClient.delete(_path(childId));
    return result['result'] == 'deleted';
  }

  /// QR content read by Vesta Tracker (see PairingPayload in the Tracker).
  static String qrPayload(String pairingCode) =>
      'vesta://link?code=${pairingCode.toUpperCase()}';
}
