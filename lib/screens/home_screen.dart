import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vesta_app/screens/app_limits_screen.dart';
import 'package:vesta_app/screens/requests_screen.dart';
import 'package:vesta_app/screens/study_mode_screen.dart';
import 'package:vesta_app/screens/zones_screen.dart';
import 'package:vesta_app/services/alert_read_state.dart';
import 'package:vesta_app/screens/map_screen.dart';
import 'package:vesta_app/screens/filters_screen.dart';
import 'package:vesta_app/screens/alerts_screen.dart';
import 'package:vesta_app/screens/reports_screen.dart';
import 'package:vesta_app/screens/device_status_screen.dart';
import 'package:vesta_app/widgets/responsive.dart';
import 'package:vesta_app/widgets/vesta_header.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

import 'package:vesta_app/l10n/tr.dart';
class HomeScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String tutorId;
  final int initialTab;

  const HomeScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.tutorId,
    this.initialTab = 0,
    this.openRequests = false,
  });

  /// Open the requests directly (from a notification).
  final bool openRequests;

  static const tabNames = ['map', 'filters', 'alerts', 'reports', 'device'];
  static const alertsTab = 2;

  static int tabFromName(String? name) {
    final index = tabNames.indexOf(name ?? '');
    return index < 0 ? 0 : index;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentTabIndex = widget.initialTab;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _childStream =
      FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .snapshots();

  late final Stream<int> _unreadStream =
      AlertReadState.unreadCountStream(widget.childId);

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _studyStream =
      FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('controls')
          .doc('study_mode')
          .snapshots();

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When a notification is opened while the screen is already visible.
    if (widget.initialTab != oldWidget.initialTab) {
      _currentTabIndex = widget.initialTab;
    }
  }

  void _selectTab(int index) {
    setState(() => _currentTabIndex = index);
    if (index == HomeScreen.alertsTab) {
      unawaited(AlertReadState.markAllSeen(widget.childId));
    }
  }

  final List<IconData> _icons = const [
    Icons.location_on_rounded,
    Icons.shield_rounded,
    Icons.notifications_active_rounded,
    Icons.analytics_rounded,
    Icons.devices_rounded,
  ];

  final List<String> _labels = [
    tr('Mapa'),
    tr('Filtros'),
    tr('Alertas'),
    tr('Reportes'),
    tr('Equipo'),
  ];

  late final Stream<int> _pendingRequests = RequestsScreen.pendingQuery(
    widget.childId,
  ).snapshots().map((s) => s.size).handleError((_) => 0);

  @override
  void initState() {
    super.initState();
    if (_currentTabIndex == HomeScreen.alertsTab) {
      unawaited(AlertReadState.markAllSeen(widget.childId));
    }
    if (widget.openRequests) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(
            RequestsScreen(childId: widget.childId),
          ));
    }
  }

  void _open(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NarrowOnWide(maxWidth: 760, child: screen)),
    );
  }

  Widget _quickActions() {
    Widget action(IconData icon, String label, VoidCallback onTap, {Widget? badge}) {
      return Expanded(
        child: Material(
          color: VestaTheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  badge ?? Icon(icon, color: VestaTheme.rose, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: VestaTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          action(Icons.place_rounded, tr('Zonas'),
              () => _open(ZonesScreen(childId: widget.childId))),
          const SizedBox(width: 8),
          action(Icons.timer_rounded, tr('Límites'),
              () => _open(AppLimitsScreen(childId: widget.childId))),
          const SizedBox(width: 8),
          action(
            Icons.front_hand_rounded,
            tr('Peticiones'),
            () => _open(RequestsScreen(childId: widget.childId)),
            badge: StreamBuilder<int>(
              stream: _pendingRequests,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: VestaTheme.warning,
                  child: const Icon(Icons.front_hand_rounded,
                      color: VestaTheme.rose, size: 22),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _childStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['nombre']?.toString() ?? widget.childName;

        // The profile was unlinked (from this or another guardian phone).
        if (data != null && data['status'] != 'vinculado') {
          return _unlinkedState(name);
        }

        return _content(name);
      },
    );
  }

  Widget _unlinkedState(String name) {
    return Scaffold(
      backgroundColor: VestaTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_rounded,
                    size: 56, color: VestaTheme.rose),
                const SizedBox(height: 16),
                Text(
                  tr('El dispositivo de {0} ya no está vinculado', [name]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VestaTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Vuelve al panel para ver el nuevo código QR y vincularlo otra vez.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: VestaTheme.textSecondary),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.dashboard_rounded),
                  label: Text(tr('Ir al panel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _studyModeCard() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _studyStream,
      builder: (context, snapshot) {
        final config = StudyModeConfig.fromDoc(snapshot.data?.data());
        final now = DateTime.now();
        final active = config.isActiveAt(now);
        final until = config.currentEnd(now);

        String subtitle;
        if (snapshot.hasError) {
          subtitle = tr('Requiere autorización de control de aplicaciones');
        } else if (active) {
          subtitle = until == null
              ? tr('Activo hasta que lo desactives')
              : tr('Activo hasta las {0}:{1}', [until.hour.toString().padLeft(2, '0'), until.minute.toString().padLeft(2, '0')]);
        } else if (config.schedules.isNotEmpty) {
          subtitle = tr('{0} horario(s) programado(s)', [config.schedules.length]);
        } else {
          subtitle = tr('Bloquea distracciones mientras estudia');
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF3B5BA5), VestaTheme.rose],
                  )
                : null,
            color: active ? null : VestaTheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: VestaTheme.beige.withValues(alpha: active ? 0 : 0.12),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: snapshot.hasError
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudyModeScreen(
                            childId: widget.childId,
                          ),
                        ),
                      ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      color: active ? Colors.white : VestaTheme.beige,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active ? tr('Modo estudio activo') : tr('Modo estudio'),
                            style: TextStyle(
                              color: VestaTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : VestaTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: VestaTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content(String childName) {
    final screens = [
      MapScreen(childId: widget.childId, tutorId: widget.tutorId),
      FiltersScreen(childId: widget.childId, tutorId: widget.tutorId),
      AlertsScreen(childId: widget.childId, tutorId: widget.tutorId),
      ReportsScreen(childId: widget.childId, tutorId: widget.tutorId),
      DeviceStatusScreen(childId: widget.childId),
    ];

    final content = IndexedStack(
      index: _currentTabIndex,
      children: screens,
    );

    // Computer: side panel with the profile and the sections, content on
    // the right. Phone: everything stacked vertically.
    if (Responsive.isWide(context)) {
      return Scaffold(
        backgroundColor: VestaTheme.background,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 330,
                child: Column(
                  children: [
                    _header(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _profileBadge(childName),
                            _studyModeCard(),
                            _quickActions(),
                            _buildSideNav(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                color: VestaTheme.beige.withValues(alpha: 0.12),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: VestaTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _profileBadge(childName),
            _studyModeCard(),
            _quickActions(),
            _buildNavbar(),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Stack(
      children: [
        const Center(child: VestaHeader(isDark: true)),
        Positioned(
          top: 15,
          right: 14,
          child: Material(
            color: VestaTheme.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.go('/'),
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(
                  Icons.people_alt_rounded,
                  color: VestaTheme.beige,
                  size: 21,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileBadge(String childName) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: VestaTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: VestaTheme.beige.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_rounded,
            color: VestaTheme.rose,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              tr('PERFIL: {0}', [childName.toUpperCase()]),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: VestaTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const Icon(
            Icons.verified_user_rounded,
            color: VestaTheme.rose,
            size: 17,
          ),
        ],
      ),
    );
  }

  Widget _buildSideNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: VestaTheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: VestaTheme.beige.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < _labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _navButton(i, vertical: true),
            ),
        ],
      ),
    );
  }

  Widget _buildNavbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: VestaTheme.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: VestaTheme.beige.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _labels.length; i++)
            Expanded(child: _navButton(i)),
        ],
      ),
    );
  }

  Widget _navButton(int index, {bool vertical = false}) {
    final active = _currentTabIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: active ? VestaTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: VestaTheme.rose.withValues(alpha: 0.28),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectTab(index),
          child: Padding(
            padding: vertical
                ? const EdgeInsets.symmetric(vertical: 13, horizontal: 16)
                : const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Flex(
              direction: vertical ? Axis.horizontal : Axis.vertical,
              mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min,
              children: [
                index == HomeScreen.alertsTab
                    ? StreamBuilder<int>(
                        stream: _unreadStream,
                        builder: (context, snapshot) {
                          final unread = snapshot.data ?? 0;
                          return Badge(
                            isLabelVisible: unread > 0 && !active,
                            label: Text(unread > 99 ? '99+' : '$unread'),
                            backgroundColor: VestaTheme.danger,
                            child: Icon(
                              _icons[index],
                              size: 17,
                              color: active
                                  ? Colors.white
                                  : VestaTheme.textSecondary,
                            ),
                          );
                        },
                      )
                    : Icon(
                        _icons[index],
                        size: 17,
                        color:
                            active ? Colors.white : VestaTheme.textSecondary,
                      ),
                SizedBox(height: vertical ? 0 : 4, width: vertical ? 14 : 0),
                Text(
                  _labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: vertical ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : VestaTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


}
