import 'package:flutter/material.dart';
import 'package:vesta_app/screens/privacy_consent_screen.dart';
import 'package:vesta_app/services/api_client.dart';

class PrivacyAccessGate extends StatefulWidget {
  final Widget child;

  const PrivacyAccessGate({
    super.key,
    required this.child,
  });

  @override
  State<PrivacyAccessGate> createState() => _PrivacyAccessGateState();
}

class _PrivacyAccessGateState extends State<PrivacyAccessGate> {
  late Future<Map<String, dynamic>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<Map<String, dynamic>> _loadStatus() {
    return VestaApiClient.get('/api/privacy/status');
  }

  Future<void> _retry() async {
    final future = _loadStatus();
    setState(() {
      _statusFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verificando autorizaciones de privacidad...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'No pudimos verificar las autorizaciones de privacidad.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final valid = snapshot.data?['valid'] == true;

        if (!valid) {
          return PrivacyConsentScreen(
            onConsentChanged: _retry,
          );
        }

        return widget.child;
      },
    );
  }
}
