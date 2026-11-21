import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vesta_app/services/auth_service.dart';

class LinkAccessGate extends StatelessWidget {
  final Widget child;
  final bool allowWhenNoChildren;

  const LinkAccessGate({
    super.key,
    required this.child,
    this.allowWhenNoChildren = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para continuar.')),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('children')
          .where('parentIds', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo comprobar la vinculación. '
                      'Revisa tu conexión e inténtalo de nuevo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // StreamBuilder volverá a suscribirse al reconstruirse.
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A1D24),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFE03131)),
            ),
          );
        }

        final children = snapshot.data?.docs ?? [];
        final hasLinkedDevice = children.any(
          (doc) => doc.data()['status'] == 'vinculado',
        );

        if (hasLinkedDevice) return child;

        if (children.isEmpty && allowWhenNoChildren) return child;

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
      backgroundColor: const Color(0xFF1A1D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111318),
        title: const Text(
          'VESTA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout, color: Colors.white70),
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
                    color: Color(0xFFE03131),
                    size: 68,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasChildren
                        ? 'Vincula el dispositivo de tu hijo'
                        : 'Antes de continuar, registra a tu hijo',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hasChildren
                        ? 'Introduce uno de los siguientes códigos en Vesta Tracker. '
                            'El panel se habilitará automáticamente cuando se complete la vinculación.'
                        : 'Para habilitar el panel de control primero debes crear un perfil '
                            'y vincular el dispositivo con Vesta Tracker.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  if (hasChildren) ...[
                    const SizedBox(height: 28),
                    ...children.map((doc) {
                      final data = doc.data();
                      final name = data['nombre']?.toString() ?? 'Menor';
                      final code = data['pairingCode']?.toString() ?? '';

                      return Card(
                        color: const Color(0xFF242831),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Código de vinculación',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                code.isEmpty ? 'Código no disponible' : code,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 25,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (code.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: code),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Código copiado.'),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copiar código'),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Text(
                      'Mantén esta pantalla abierta. Detectaremos la vinculación automáticamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ] else ...[
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/add-child'),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar menor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE03131),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
