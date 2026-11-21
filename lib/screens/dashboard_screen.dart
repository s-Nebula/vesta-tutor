import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vesta_app/services/api_client.dart';
import 'package:vesta_app/services/auth_service.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _desvincularHijo(
    BuildContext context,
    String hijoId,
  ) async {
    try {
      final data = await VestaApiClient.post(
        '/api/children/${Uri.encodeComponent(hijoId)}/unlink',
      );
      final codigo = data['pairingCode'] as String? ?? '';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              codigo.isEmpty
                  ? 'Menor desvinculado correctamente.'
                  : 'Dispositivo desvinculado. Nuevo código: $codigo',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al desvincular: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al desvincular: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'PANEL DE CONTROL',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'VESTA · PROTECCIÓN FAMILIAR',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.5,
                color: VestaTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text('Inicia sesión para continuar'),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('children')
                  .where('parentIds', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: VestaTheme.rose,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar los dispositivos.'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _emptyState(context);
                }

                final hijos = snapshot.data!.docs;
                final vinculados = hijos.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == 'vinculado';
                }).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                  children: [
                    _welcomeCard(hijos.length, vinculados),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'DISPOSITIVOS FAMILIARES',
                            style: TextStyle(
                              color: VestaTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        _counter(hijos.length),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...hijos.map((doc) {
                      final hijo = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: _childCard(
                          context,
                          hijo,
                          doc.id,
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/add-child'),
        backgroundColor: VestaTheme.rose,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Añadir dispositivo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _welcomeCard(int total, int vinculados) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: VestaTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: VestaTheme.rose.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 17),
          const Text(
            'Tu familia, protegida.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Gestiona los dispositivos vinculados a tu cuenta.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _welcomeStat('DISPOSITIVOS', '$total'),
              const SizedBox(width: 28),
              _welcomeStat('VINCULADOS', '$vinculados'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _welcomeStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _counter(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: VestaTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: VestaTheme.beige.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        '$total registrados',
        style: const TextStyle(
          color: VestaTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _childCard(
    BuildContext context,
    Map<String, dynamic> hijo,
    String hijoId,
  ) {
    final bool estaVinculado = hijo['status'] == 'vinculado';
    final String nombre = hijo['nombre'] ?? 'Sin nombre';

    return Container(
      decoration: BoxDecoration(
        color: VestaTheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: VestaTheme.beige.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: () {
            if (estaVinculado) {
              context.go('/home/$hijoId', extra: nombre);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('El menor aún no está vinculado.'),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: estaVinculado
                          ? [
                              VestaTheme.wine,
                              VestaTheme.rose,
                            ]
                          : [
                              VestaTheme.surfaceLight,
                              VestaTheme.burgundy,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (estaVinculado
                                ? VestaTheme.rose
                                : VestaTheme.beige)
                            .withValues(alpha: 0.18),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    estaVinculado
                        ? Icons.phonelink_ring_rounded
                        : Icons.phonelink_setup_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VestaTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _statusLabel(estaVinculado),
                      if (!estaVinculado) ...[
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: VestaTheme.burgundy.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            'CÓDIGO  ${hijo['pairingCode'] ?? 'N/A'}',
                            style: const TextStyle(
                              color: VestaTheme.beige,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (estaVinculado)
                  IconButton(
                    tooltip: 'Desvincular dispositivo',
                    onPressed: () => _desvincularHijo(context, hijoId),
                    icon: const Icon(
                      Icons.link_off_rounded,
                      color: VestaTheme.rose,
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: VestaTheme.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusLabel(bool vinculado) {
    final color = vinculado ? const Color(0xFF72D6A0) : VestaTheme.beige;

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Text(
          vinculado ? 'Dispositivo vinculado' : 'Esperando vinculación',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: VestaTheme.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: VestaTheme.rose.withValues(alpha: 0.25),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: const Icon(
                Icons.devices_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 23),
            const Text(
              'Aún no hay dispositivos',
              style: TextStyle(
                color: VestaTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Añade un dispositivo para comenzar a gestionar la protección familiar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VestaTheme.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => context.go('/add-child'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir dispositivo'),
            ),
          ],
        ),
      ),
    );
  }
}
