import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class VestaApiClient {
  static const String _baseUrl = String.fromEnvironment('VESTA_API_URL');

  static final http.Client _client = http.Client();

  static Future<Map<String, dynamic>> get(String path) async {
    if (_baseUrl.isEmpty) {
      throw Exception('Falta configurar VESTA_API_URL.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No existe una sesión autenticada.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('No se pudo obtener el token de autenticación.');
    }
    final baseUrl = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw Exception('El servidor devolvió una respuesta no válida.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'Error del servidor (${response.statusCode}).';
      throw Exception(message);
    }
    if (decoded is! Map) {
      throw Exception('El servidor devolvió una respuesta inesperada.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    if (_baseUrl.isEmpty) {
      throw Exception('Falta configurar VESTA_API_URL.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No existe una sesión autenticada.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('No se pudo obtener el token de autenticación.');
    }

    final baseUrl = _baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$baseUrl$path');

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw Exception('El servidor devolvió una respuesta no válida.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'Error del servidor (${response.statusCode}).';
      throw Exception(message);
    }

    if (decoded is! Map) {
      throw Exception('El servidor devolvió una respuesta inesperada.');
    }

    return Map<String, dynamic>.from(decoded);
  }
}
