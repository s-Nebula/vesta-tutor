import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vesta_app/services/child_profile_service.dart';
import 'package:vesta_app/widgets/pairing_card.dart';
import 'package:vesta_app/widgets/responsive.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _desvincularHijo(
    BuildContext context,
    String hijoId,
    String nombre,
  ) async {
    // Previously one accidental tap on the icon was enough to unlink.
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('¿Desvincular el dispositivo de {0}?', [nombre])),
        content: Text(
          tr('Dejarás de recibir su ubicación, alertas y reportes, y se desactivarán los filtros en su teléfono. El perfil se conserva y podrás vincularlo de nuevo con un código nuevo.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VestaTheme.wine),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Desvincular')),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await ChildProfileService.unlink(hijoId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('Dispositivo desvinculado. Toca el perfil para ver el nuevo QR.'),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al desvincular: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al desvincular: {0}', [e]))),
        );
      }
    }
  }

  Future<void> _eliminarPerfil(
    BuildContext context,
    String hijoId,
    String nombre,
    bool compartido,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('¿Eliminar el perfil de {0}?', [nombre])),
        content: Text(
          compartido
              ? tr('Otros tutores comparten este perfil: dejará de aparecer en tu panel, pero ellos lo conservarán con todos sus datos.')
              : tr('Se borrarán su historial de ubicación, alertas, reportes, zonas y ajustes, y se desvinculará su teléfono. Esta acción no se puede deshacer.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VestaTheme.wine),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Eliminar')),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      final borrado = await ChildProfileService.delete(hijoId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              borrado
                  ? tr('Perfil de {0} eliminado.', [nombre])
                  : tr('Ya no compartes el perfil de {0}.', [nombre]),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al eliminar el perfil: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Error al eliminar el perfil: {0}', [e]))),
        );
      }
    }
  }

  void _editarPerfil(
    BuildContext context,
    String hijoId,
    Map<String, dynamic> hijo,
  ) {
    context.push('/add-child', extra: {
      'childId': hijoId,
      'nombre': hijo['nombre'],
      'edad': hijo['edad'],
      'color': hijo['color'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: VestaTheme.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              tr('PANEL DE CONTROL'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 3),
            Text(
              tr('VESTA · PROTECCIÓN FAMILIAR'),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: VestaTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('Ajustes'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? Center(
              child: Text(tr('Inicia sesión para continuar')),
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
                  return Center(
                    child: Text(tr('No se pudieron cargar los dispositivos.')),
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

                final cabecera = Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('DISPOSITIVOS FAMILIARES'),
                        style: TextStyle(
                          color: VestaTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    _counter(hijos.length),
                  ],
                );

                // Computer: summary on the left, minors in a grid.
                if (Responsive.isWide(context)) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const gap = 14.0;
                          final gridWidth = constraints.maxWidth - 64 - 340 - 28;
                          final columns = gridWidth >= 900 ? 3 : (gridWidth >= 560 ? 2 : 1);
                          final cardWidth = (gridWidth - gap * (columns - 1)) / columns;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(32, 20, 32, 110),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 340,
                                  child: _welcomeCard(hijos.length, vinculados),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      cabecera,
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: gap,
                                        runSpacing: gap,
                                        children: [
                                          for (final doc in hijos)
                                            SizedBox(
                                              width: cardWidth,
                                              child: _childCard(
                                                context,
                                                doc.data() as Map<String, dynamic>,
                                                doc.id,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                  children: [
                    _welcomeCard(hijos.length, vinculados),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('DISPOSITIVOS FAMILIARES'),
                            style: TextStyle(
                              color: VestaTheme.textSecondary,
                              fontSize: 12,
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
        label: Text(
          tr('Añadir dispositivo'),
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
          Text(
            tr('Tu familia, protegida.'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr('Gestiona los dispositivos vinculados a tu cuenta.'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _welcomeStat(tr('DISPOSITIVOS'), '$total'),
              const SizedBox(width: 28),
              _welcomeStat(tr('VINCULADOS'), '$vinculados'),
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
            fontSize: 12,
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
        style: TextStyle(
          color: VestaTheme.textSecondary,
          fontSize: 12,
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
    final String nombre = (hijo['nombre'] ?? tr('Sin nombre')).toString();
    final int? colorValue = hijo['color'] is int ? hijo['color'] as int : null;
    final Color avatarColor =
        colorValue == null ? VestaTheme.rose : Color(colorValue);
    final String inicial =
        nombre.trim().isEmpty ? '?' : nombre.trim()[0].toUpperCase();
    final edad = hijo['edad'];

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
              showPairingSheet(
                context,
                childId: hijoId,
                childName: nombre,
                pairingCode: hijo['pairingCode']?.toString() ?? '',
                expiresAt: pairingExpiryOf(hijo),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: avatarColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: VestaTheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          estaVinculado
                              ? Icons.phonelink_ring_rounded
                              : Icons.qr_code_rounded,
                          size: 15,
                          color: estaVinculado
                              ? const Color(0xFF72D6A0)
                              : VestaTheme.beige,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edad is int ? tr('{0} · {1} años', [nombre, edad]) : nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: VestaTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      _statusLabel(estaVinculado),
                      if (!estaVinculado) ...[
                        const SizedBox(height: 6),
                        Text(
                          tr('Toca para ver el código QR'),
                          style: TextStyle(
                            color: VestaTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: tr('Opciones'),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: VestaTheme.textSecondary,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editarPerfil(context, hijoId, hijo);
                      case 'qr':
                        showPairingSheet(
                          context,
                          childId: hijoId,
                          childName: nombre,
                          pairingCode: hijo['pairingCode']?.toString() ?? '',
                expiresAt: pairingExpiryOf(hijo),
                        );
                      case 'unlink':
                        _desvincularHijo(context, hijoId, nombre);
                      case 'delete':
                        final parentIds = hijo['parentIds'];
                        _eliminarPerfil(
                          context,
                          hijoId,
                          nombre,
                          parentIds is List && parentIds.length > 1,
                        );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_rounded),
                        title: Text(tr('Editar perfil')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!estaVinculado)
                      PopupMenuItem(
                        value: 'qr',
                        child: ListTile(
                          leading: Icon(Icons.qr_code_rounded),
                          title: Text(tr('Código de vinculación')),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (estaVinculado)
                      PopupMenuItem(
                        value: 'unlink',
                        child: ListTile(
                          leading: Icon(
                            Icons.link_off_rounded,
                            color: VestaTheme.rose,
                          ),
                          title: Text(tr('Desvincular dispositivo')),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: VestaTheme.rose,
                        ),
                        title: Text(tr('Eliminar perfil')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
          vinculado ? tr('Dispositivo vinculado') : tr('Esperando vinculación'),
          style: TextStyle(
            color: color,
            fontSize: 12,
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
            Text(
              tr('Aún no hay dispositivos'),
              style: TextStyle(
                color: VestaTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              tr('Añade un dispositivo para comenzar a gestionar la protección familiar.'),
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
              label: Text(tr('Añadir dispositivo')),
            ),
          ],
        ),
      ),
    );
  }
}
