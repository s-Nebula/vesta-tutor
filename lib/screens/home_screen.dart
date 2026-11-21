import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vesta_app/services/auth_service.dart';
import 'package:vesta_app/screens/map_screen.dart';
import 'package:vesta_app/screens/filters_screen.dart';
import 'package:vesta_app/screens/alerts_screen.dart';
import 'package:vesta_app/screens/reports_screen.dart';
import 'package:vesta_app/screens/device_status_screen.dart';
import 'package:vesta_app/widgets/vesta_header.dart';
import 'package:vesta_app/theme/vesta_theme.dart';

class HomeScreen extends StatefulWidget {
  final String childId;
  final String childName;
  final String tutorId;

  const HomeScreen({
    super.key,
    required this.childId,
    required this.childName,
    required this.tutorId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  final List<IconData> _icons = const [
    Icons.location_on_rounded,
    Icons.shield_rounded,
    Icons.notifications_active_rounded,
    Icons.analytics_rounded,
    Icons.devices_rounded,
  ];

  final List<String> _labels = const [
    'Mapa',
    'Filtros',
    'Alertas',
    'Reportes',
    'Equipo',
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      MapScreen(childId: widget.childId, tutorId: widget.tutorId),
      FiltersScreen(childId: widget.childId, tutorId: widget.tutorId),
      AlertsScreen(childId: widget.childId, tutorId: widget.tutorId),
      ReportsScreen(childId: widget.childId, tutorId: widget.tutorId),
      DeviceStatusScreen(childId: widget.childId),
    ];

    return Scaffold(
      backgroundColor: VestaTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
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
            ),
            Container(
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
                      'PERFIL: ${widget.childName.toUpperCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VestaTheme.textSecondary,
                        fontSize: 11,
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
            ),
            _buildNavbar(),
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: screens,
              ),
            ),
          ],
        ),
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
          _logoutButton(),
        ],
      ),
    );
  }

  Widget _navButton(int index) {
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
          onTap: () => setState(() => _currentTabIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _icons[index],
                  size: 17,
                  color: active ? Colors.white : VestaTheme.textSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
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

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Material(
        color: VestaTheme.surfaceLight,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () async {
            await AuthService().signOut();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 9, vertical: 11),
            child: Icon(
              Icons.logout_rounded,
              color: VestaTheme.rose,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}
