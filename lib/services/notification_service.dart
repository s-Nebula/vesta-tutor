import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> inicializarNotificaciones() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(initializationSettings);

    const channel = AndroidNotificationChannel(
      'vesta_critical_alerts',
      'Alertas Críticas Vesta',
      description:
          'Canal destinado a reportar incidentes de seguridad inmediatos.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      final token = await _fcm.getToken();

      if (token != null) {
        await _guardarTokenEnFirestore(token);
      }

      _tokenSubscription ??= _fcm.onTokenRefresh.listen(
        _guardarTokenEnFirestore,
      );
    }

    _authSubscription ??= _auth.authStateChanges().listen((user) async {
      if (user == null) return;

      try {
        final token = await _fcm.getToken();
        if (token != null) {
          await _guardarTokenEnFirestore(token);
        }
      } catch (e) {
        debugPrint('Error actualizando token FCM: $e');
      }
    });
  }

  Future<void> _guardarTokenEnFirestore(String token) async {
    final user = _auth.currentUser;

    if (user == null || user.isAnonymous) return;

    try {
      final userRef = _db.collection('users').doc(user.uid);

      await userRef.set({
        'uid': user.uid,
        'email': user.email?.trim().toLowerCase(),
        'role': 'tutor',
      }, SetOptions(merge: true));

      await userRef.collection('fcmTokens').doc(token).set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }

  Future<void> mostrarNotificacionInmediata({
    required String titulo,
    required String subtitulo,
    required String tipo,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'vesta_critical_alerts',
      'Alertas Críticas Vesta',
      importance: Importance.max,
      priority: Priority.high,
      color: tipo == 'critical'
          ? const Color(0xFFE03131)
          : const Color(0xFFFCC419),
      playSound: true,
      enableLights: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '🚨 VESTA: $titulo',
      subtitulo,
      details,
    );
  }
}
