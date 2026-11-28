import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vesta_app/features/auth/forgot_password_screen.dart';
import 'package:vesta_app/features/auth/login_screen.dart';
import 'package:vesta_app/features/auth/register_screen.dart';
import 'package:vesta_app/screens/alerts_screen.dart';
import 'package:vesta_app/screens/add_child_screen.dart';
import 'package:vesta_app/screens/dashboard_screen.dart';
import 'package:vesta_app/screens/filters_screen.dart';
import 'package:vesta_app/screens/home_screen.dart';
import 'package:vesta_app/screens/reports_screen.dart';
import 'package:vesta_app/screens/privacy_consent_screen.dart';
import 'package:vesta_app/screens/delete_account_screen.dart';
import 'package:vesta_app/screens/settings_screen.dart';
import 'package:vesta_app/widgets/link_access_gate.dart';
import 'package:vesta_app/widgets/privacy_access_gate.dart';
import 'package:vesta_app/widgets/responsive.dart';

import 'package:vesta_app/l10n/tr.dart';
class AppRouter {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Widget _protected(Widget screen) {
    return PrivacyAccessGate(
      child: LinkAccessGate(child: screen),
    );
  }

  /// Main dashboard: reachable when there are profiles even if they are not
  /// linked, so their QR can be shown, edited or another one added.
  Widget _dashboard() {
    return const PrivacyAccessGate(
      child: LinkAccessGate(
        allowUnlinkedChildren: true,
        child: DashboardScreen(),
      ),
    );
  }

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Vesta')),
      body: Center(child: Text(tr('La pantalla solicitada no existe.'))),
    ),
    redirect: (context, state) {
      final user = auth.currentUser;
      final location = state.matchedLocation;
      final isAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';

      if (user == null) {
        return isAuthRoute ? null : '/login';
      }

      if (user.isAnonymous) return '/login';

      if (isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => _dashboard(),
      ),
      // Explicit alias so old navigations don't end up in the errorBuilder
      // and skip the linking check.
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => _dashboard(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const NarrowOnWide(child: LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const NarrowOnWide(child: RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const NarrowOnWide(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const NarrowOnWide(child: SettingsScreen()),
      ),
      GoRoute(
        path: '/delete-account',
        builder: (context, state) => const NarrowOnWide(child: DeleteAccountScreen()),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const NarrowOnWide(child: PrivacyConsentScreen()),
      ),
      GoRoute(
        path: '/add-child',
        builder: (context, state) => NarrowOnWide(
          child: PrivacyAccessGate(
            child: LinkAccessGate(
              allowWhenNoChildren: true,
              allowUnlinkedChildren: true,
              child: AddChildScreen(
                childData: state.extra as Map<String, dynamic>?,
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home/:childId',
        builder: (context, state) {
          final childId = state.pathParameters['childId'] ?? '';
          if (childId.isEmpty) {
            return _protected(const DashboardScreen());
          }

          final extra = state.extra;
          final childName = extra is Map<String, dynamic>
              ? (extra['childName'] ?? tr('Menor')).toString()
              : (extra is String ? extra : tr('Menor'));

          return _protected(
            HomeScreen(
              childId: childId,
              childName: childName,
              tutorId: auth.currentUser?.uid ?? '',
              initialTab: HomeScreen.tabFromName(
                state.uri.queryParameters['tab'],
              ),
              openRequests: state.uri.queryParameters['open'] == 'requests',
            ),
          );
        },
      ),
      ...['filters', 'alerts', 'reports'].map(
        (route) => GoRoute(
          path: '/$route/:childId',
          builder: (context, state) {
            final childId = state.pathParameters['childId'] ?? '';
            final tutorId = auth.currentUser?.uid ?? '';

            switch (route) {
              case 'filters':
                return NarrowOnWide(
                  maxWidth: 900,
                  child: _protected(
                    FiltersScreen(childId: childId, tutorId: tutorId),
                  ),
                );
              case 'alerts':
                return NarrowOnWide(
                  maxWidth: 900,
                  child: _protected(
                    AlertsScreen(childId: childId, tutorId: tutorId),
                  ),
                );
              case 'reports':
                return NarrowOnWide(
                  maxWidth: 900,
                  child: _protected(
                    ReportsScreen(childId: childId, tutorId: tutorId),
                  ),
                );
              default:
                return _protected(const DashboardScreen());
            }
          },
        ),
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    stream.listen((_) => notifyListeners());
  }
}
