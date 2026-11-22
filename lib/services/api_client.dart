import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:vesta_app/l10n/tr.dart';
/// API error. [isNetworkError] tells "no connection" apart from a server
/// response, so cached data can keep being shown.
class VestaApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final bool isNetworkError;

  const VestaApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.isNetworkError = false,
  });

  bool get isTransient =>
      isNetworkError ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() => message;
}

class VestaApiClient {
  static const String _baseUrl = String.fromEnvironment('VESTA_API_URL');

  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>> get(String path) =>
      _send('GET', path, null);

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const {},
  }) =>
      _send('POST', path, body);

  static Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, dynamic> body,
  }) =>
      _send('PATCH', path, body);

  static Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    if (_baseUrl.isEmpty) {
      throw VestaApiException(tr('Falta configurar VESTA_API_URL.'));
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw VestaApiException(tr('No existe una sesión autenticada.'));
    }

    String? token;
    try {
      token = await user.getIdToken();
    } on FirebaseAuthException catch (e) {
      throw VestaApiException(
        tr('No se pudo obtener el token de autenticación.'),
        code: e.code,
        isNetworkError: e.code == 'network-request-failed',
      );
    }

    if (token == null || token.isEmpty) {
      throw VestaApiException(
        tr('No se pudo obtener el token de autenticación.'),
      );
    }

    final baseUrl = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      });

    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw VestaApiException(
        tr('El servidor tardó demasiado en responder.'),
        isNetworkError: true,
      );
    } on http.ClientException {
      throw VestaApiException(
        tr('Sin conexión con el servidor. Comprueba tu internet.'),
        isNetworkError: true,
      );
    } catch (e) {
      // SocketException / HandshakeException (dart:io) on mobile.
      throw VestaApiException(
        tr('Error de conexión: {0}', [e]),
        isNetworkError: true,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw VestaApiException(
        tr('El servidor devolvió una respuesta no válida.'),
        statusCode: response.statusCode >= 500 ? response.statusCode : 502,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : tr('Error del servidor ({0}).', [response.statusCode]);
      final code = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : null;
      throw VestaApiException(
        message,
        statusCode: response.statusCode,
        code: code,
      );
    }

    if (decoded is! Map) {
      throw VestaApiException(
        tr('El servidor devolvió una respuesta inesperada.'),
      );
    }

    return Map<String, dynamic>.from(decoded);
  }
}
