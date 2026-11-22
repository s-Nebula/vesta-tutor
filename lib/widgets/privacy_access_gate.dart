import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vesta_app/screens/privacy_consent_screen.dart';
import 'package:vesta_app/services/api_client.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Checks that the guardian has a valid privacy consent.
///
/// Offline, this user's last valid result is used (max. 7 days) so the app is
/// not blocked: the data shown comes from the Firestore cache and the security
/// rules are still enforced on the server. Meanwhile it retries automatically
/// every 15 s.
class PrivacyAccessGate extends StatefulWidget {
  final Widget child;

  const PrivacyAccessGate({
    super.key,
    required this.child,
  });

  /// Forgets the in-memory result (after accepting or revoking consent).
  static void invalidate() => _PrivacyAccessGateState._sessionValidAt = null;

  @override
  State<PrivacyAccessGate> createState() => _PrivacyAccessGateState();
}

enum _GateState { loading, valid, invalid, offlineCached, error }

class _PrivacyAccessGateState extends State<PrivacyAccessGate> {
  static const Duration _cacheMaxAge = Duration(days: 7);
  static const Duration _retryEvery = Duration(seconds: 15);

  /// Result shared by every protected screen in the session: avoids a server
  /// request on each screen change.
  static String? _sessionUid;
  static DateTime? _sessionValidAt;

  _GateState _state = _GateState.loading;
  Object? _error;
  Timer? _retryTimer;

  String get _cacheKey =>
      'privacy_valid_at_${FirebaseAuth.instance.currentUser?.uid ?? ''}';

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final validAt = _sessionValidAt;
    if (uid != null &&
        uid == _sessionUid &&
        validAt != null &&
        DateTime.now().difference(validAt) < const Duration(minutes: 5)) {
      _state = _GateState.valid;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await VestaApiClient.get('/api/privacy/status');
      final valid = status['valid'] == true;
      final prefs = await SharedPreferences.getInstance();

      if (valid) {
        await prefs.setInt(_cacheKey, DateTime.now().millisecondsSinceEpoch);
        _sessionUid = FirebaseAuth.instance.currentUser?.uid;
        _sessionValidAt = DateTime.now();
      } else {
        await prefs.remove(_cacheKey);
        _sessionValidAt = null;
      }

      _retryTimer?.cancel();
      _retryTimer = null;
      if (mounted) {
        setState(() => _state = valid ? _GateState.valid : _GateState.invalid);
      }
    } catch (error) {
      final transient = error is VestaApiException && error.isTransient;
      final cached = transient && await _hasRecentValidCache();

      if (!mounted) return;
      setState(() {
        _error = error;
        _state = cached ? _GateState.offlineCached : _GateState.error;
      });

      if (transient) {
        _retryTimer ??= Timer.periodic(_retryEvery, (_) => _load());
      }
    }
  }

  Future<bool> _hasRecentValidCache() async {
    final prefs = await SharedPreferences.getInstance();
    final validAtMs = prefs.getInt(_cacheKey);
    if (validAtMs == null) return false;

    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(validAtMs),
    );
    return !age.isNegative && age < _cacheMaxAge;
  }

  Future<void> _retry() async {
    setState(() => _state = _GateState.loading);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _GateState.loading:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(tr('Verificando autorizaciones de privacidad...')),
              ],
            ),
          ),
        );

      case _GateState.valid:
      case _GateState.offlineCached:
        return widget.child;

      case _GateState.invalid:
        return PrivacyConsentScreen(onConsentChanged: _retry);

      case _GateState.error:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    tr('No pudimos verificar las autorizaciones de privacidad.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_retryTimer != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('Reintentaremos automáticamente al recuperar la conexión.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: Text(tr('Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
