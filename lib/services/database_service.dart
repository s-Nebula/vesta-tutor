import 'package:firebase_auth/firebase_auth.dart';
import 'package:vesta_app/services/api_client.dart';

import 'package:vesta_app/l10n/tr.dart';
class DatabaseService {
  Future<Map<String, dynamic>> crearNuevoHijo(
    String nombre,
    int edad,
    int colorValue,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw Exception(tr('Debes iniciar sesión como tutor.'));
    }

    final nombreLimpio = nombre.trim();
    if (nombreLimpio.isEmpty || nombreLimpio.length > 80) {
      throw Exception(tr('El nombre debe tener entre 1 y 80 caracteres.'));
    }
    if (edad < 0) {
      throw Exception(tr('La edad no puede ser negativa.'));
    }
    if (colorValue < 0 || colorValue > 0xFFFFFFFF) {
      throw Exception(tr('El color del perfil no es válido.'));
    }

    final result = await VestaApiClient.post(
      '/api/children',
      body: {
        'nombre': nombreLimpio,
        'edad': edad,
        'color': colorValue,
      },
    );

    final childId = result['childId'];
    final pairingCode = result['pairingCode'];

    if (childId is! String || pairingCode is! String) {
      throw Exception(tr('El servidor devolvió una respuesta incompleta.'));
    }

    return {
      'childId': childId,
      'pairingCode': pairingCode,
    };
  }
}
