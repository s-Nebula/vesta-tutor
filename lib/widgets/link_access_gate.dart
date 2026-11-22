import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vesta_app/services/auth_service.dart';
import 'package:vesta_app/theme/vesta_theme.dart';
import 'package:vesta_app/widgets/pairing_card.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Requires the guardian to have at least one profile (and, by default, at
/// least one linked device) before showing [child].
class LinkAccessGate extends StatefulWidget {
  final Widget child;

  /// Allows access when no profile exists yet (sign-up).
  final bool allowWhenNoChildren;

  /// Allows access when there are profiles even if none is linked
  /// (main dashboard: from there profiles are edited, the QR shown or another added).
  final bool allowUnlinkedChildren;

  const LinkAccessGate({
    super.key,
    required this.child,
    this.allowWhenNoChildren = false,
    this.allowUnlinkedChildren = false,
  });

  @override
  State<LinkAccessGate> createState() => _LinkAccessGateState();
}

class _LinkAccessGateState extends State<LinkAccessGate> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String? _uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamFor(String uid) {
    // Created once: a new Firestore subscription used to be opened on every
    // widget rebuild.
    if (_stream == null || _uid != uid) {
      _uid = uid;
      _stream = FirebaseFirestore.instance
          .collection('children')
          .where('parentIds', arrayContains: uid)
          .snapshots();
    }
    return _stream!;
  }

  void _retry() => setState(() => _stream = null);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return Scaffold(
        body: Center(child: Text(tr('Inicia sesión para continuar.'))),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _streamFor(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError && !snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      tr('No se pudo comprobar la vinculación. Revisa tu conexión e inténtalo de nuevo.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: Text(tr('Reintentar')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: VestaTheme.background,
            body: Center(
              child: CircularProgressIndicator(color: VestaTheme.rose),
            ),
          );
        }

        final children = snapshot.data!.docs;
        final hasLinkedDevice = children.any(
          (doc) => doc.data()['status'] == 'vinculado',
        );

        if (hasLinkedDevice) return widget.child;
        if (children.isEmpty && widget.allowWhenNoChildren) return widget.child;
        if (children.isNotEmpty && widget.allowUnlinkedChildren) {
          return widget.child;
        }

        return _PairingRequiredScreen(children: children);
      },
    );
  }
}

class _PairingRequiredScreen extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> children;

  const _PairingRequiredScreen({required this.children});

  @override
  Widget build(BuildContext context) {
    final hasChildren = children.isNotEmpty;

    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(
        title: const Text(
          'VESTA',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          if (hasChildren)
            IconButton(
              tooltip: tr('Ir al panel'),
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.dashboard_rounded),
            ),
          IconButton(
            tooltip: tr('Cerrar sesión'),
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.phonelink_lock,
                    color: VestaTheme.rose,
                    size: 64,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    hasChildren
                        ? tr('Vincula el dispositivo de tu hijo')
                        : tr('Antes de continuar, registra a tu hijo'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: VestaTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasChildren
                        ? tr('Instala Vesta Tracker en su teléfono y escanea el código QR. Esta pantalla se actualizará sola cuando termine la vinculación.')
                        : tr('Para habilitar el panel de control primero debes crear un perfil y vincular el dispositivo con Vesta Tracker.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: VestaTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (hasChildren)
                    ...children.map((doc) {
                      final data = doc.data();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PairingCard(
                          childId: doc.id,
                          childName: data['nombre']?.toString() ?? tr('Menor'),
                          pairingCode: data['pairingCode']?.toString() ?? '',
                          expiresAt: pairingExpiryOf(data),
                        ),
                      );
                    })
                  else
                    ElevatedButton.icon(
                      onPressed: () => context.go('/add-child'),
                      icon: const Icon(Icons.add),
                      label: Text(tr('Registrar menor')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VestaTheme.rose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
