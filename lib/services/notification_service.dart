import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:vesta_app/theme/vesta_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Guardian notifications (FCM push + local notices).
///
/// Fixes compared with the previous version:
/// * The Android channel matches the one the server uses (`vesta_alerts`).
///   The app used to create `vesta_critical_alerts`, so Android showed the
///   pushes in the generic channel, without high priority.
/// * Pushes that arrive while the app is open are shown (Android does not do
///   it by itself in the foreground).
/// * Tapping a notification opens the matching minor's alerts.
/// * The same alert is not shown twice (push + local listener).
/// * The token is removed on sign-out so a shared phone does not keep
///   receiving another account's alerts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  factory NotificationService() => instance;

  static const String channelId = 'vesta_alerts';
  static const String _legacyChannelId = 'vesta_critical_alerts';

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  bool _initialized = false;
  void Function(String childId, String kind)? _open;
  (String, String)? _pending;

  /// IDs of alerts already shown in this session (push or local).
  final Set<String> _shownAlertIds = {};

  /// Registers how to navigate when a notice is tapped. `kind` is `alert`,
  /// `request` or `weekly_summary`.
  void setNavigationHandler(void Function(String childId, String kind) open) {
    _open = open;
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      open(pending.$1, pending.$2);
    }
  }

  /// [payload] is `childId` or `childId|kind`.
  void _handleTap(String? payload, [String? kind]) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    final childId = parts.first;
    final resolvedKind = kind ?? (parts.length > 1 ? parts[1] : 'alert');
    final handler = _open;
    if (handler == null) {
      _pending = (childId, resolvedKind);
    } else {
      handler(childId, resolvedKind);
    }
  }

  static String _kindOf(Map<String, dynamic> data) =>
      data['kind']?.toString() ?? 'alert';

  Future<void> inicializarNotificaciones() async {
    if (_initialized) return;
    _initialized = true;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) =>
          _handleTap(response.payload),
    );

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        tr('Alertas de Vesta'),
        description: tr('Incidentes de seguridad de los dispositivos vinculados.'),
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.deleteNotificationChannel(_legacyChannelId);

    // App opened from a local notification while it was closed.
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _handleTap(launch?.notificationResponse?.payload);
    }

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final permitted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (permitted) {
      await _saveCurrentToken();
      _tokenSubscription ??= _fcm.onTokenRefresh.listen(_saveToken);
    }

    // Push received with the app in the foreground.
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final notification = message.notification;
      unawaited(mostrarNotificacionInmediata(
        titulo: notification?.title ?? tr('Alerta'),
        subtitulo: notification?.body ?? tr('Vesta ha registrado una alerta.'),
        tipo: data['type']?.toString() ?? 'critical',
        alertId: data['alertId']?.toString() ??
            data['requestId']?.toString() ??
            message.messageId,
        childId: data['childId']?.toString(),
        kind: _kindOf(data),
        yaFormateado: true,
      ));
    });

    // Push tapped with the app in the background or closed.
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleTap(
        message.data['childId']?.toString(),
        _kindOf(message.data),
      ),
    );
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleTap(
        initialMessage.data['childId']?.toString(),
        _kindOf(initialMessage.data),
      );
    }

    _authSubscription ??= _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      await _saveCurrentToken();
    });
  }

  /// Call after the user changes the app language, so the server sends
  /// this device's pushes in the new language.
  Future<void> syncLanguage() => _saveCurrentToken();

  Future<void> _saveCurrentToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('Error actualizando token FCM: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      final userRef = _db.collection('users').doc(user.uid);

      await userRef.set({
        'uid': user.uid,
        'email': user.email?.trim().toLowerCase(),
        'role': 'tutor',
      }, SetOptions(merge: true));

      // `lang` tells the server which language to write this device's pushes in.
      await userRef.collection('fcmTokens').doc(token).set({
        'token': token,
        'lang': appLanguage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }

  /// Must be called BEFORE signing out (there are still permissions to delete).
  Future<void> unregisterCurrentDevice() async {
    final user = _auth.currentUser;
    try {
      final token = await _fcm.getToken();
      if (user != null && token != null) {
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(token)
            .delete()
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('No se pudo eliminar el token FCM: $e');
    }

    try {
      // Invalidates the token: even if the deletion above failed offline,
      // the server will clean up the invalid token on the next send.
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('No se pudo invalidar el token FCM: $e');
    }

    _shownAlertIds.clear();
  }

  Future<void> mostrarNotificacionInmediata({
    required String titulo,
    required String subtitulo,
    required String tipo,
    String? alertId,
    String? childId,
    String kind = 'alert',
    bool yaFormateado = false,
  }) async {
    if (alertId != null && !_shownAlertIds.add(alertId)) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      tr('Alertas de Vesta'),
      importance: Importance.max,
      priority: Priority.high,
      color: switch (tipo) {
        'critical' => VestaTheme.danger,
        'warning' => VestaTheme.warning,
        _ => VestaTheme.info,
      },
      playSound: true,
      enableLights: true,
    );

    await _localNotifications.show(
      (alertId ?? DateTime.now().toIso8601String()).hashCode & 0x7fffffff,
      yaFormateado ? titulo : tr('VESTA: {0}', [titulo]),
      subtitulo,
      NotificationDetails(android: androidDetails),
      payload: childId == null ? null : '$childId|$kind',
    );
  }
}
