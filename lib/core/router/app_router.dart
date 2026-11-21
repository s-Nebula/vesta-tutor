import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vesta_app/features/auth/forgot_password_screen.dart';
import 'package:vesta_app/features/auth/login_screen.dart';
import 'package:vesta_app/features/auth/register_screen.dart';
import 'package:vesta_app/screens/alerts_screen.dart';
import 'package:vesta_app/screens/add_child_screen.dart';
import 'package:vesta_app/screens/crear_hijo_screen.dart';
import 'package:vesta_app/screens/dashboard_screen.dart';
import 'package:vesta_app/screens/filters_screen.dart';
import 'package:vesta_app/screens/home_screen.dart';
import 'package:vesta_app/screens/reports_screen.dart';
import 'package:vesta_app/screens/privacy_consent_screen.dart';
import 'package:vesta_app/widgets/link_access_gate.dart';
import 'package:vesta_app/widgets/privacy_access_gate.dart';

class AppRouter {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Widget _protected(Widget screen) {
    return PrivacyAccessGate(
      child: LinkAccessGate(child: screen),
    );
  }

  late final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Vesta')),
      body: const Center(child: Text('La pantalla solicitada no existe.')),
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
        builder: (context, state) => _protected(const DashboardScreen()),
      ),
      // Alias explícito para evitar que navegaciones antiguas terminen
      // en el errorBuilder y se salten la comprobación de vinculación.
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => _protected(const DashboardScreen()),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyConsentScreen(),
      ),
      GoRoute(
        path: '/add-child',
        builder: (context, state) => PrivacyAccessGate(
          child: LinkAccessGate(
            allowWhenNoChildren: true,
            child: AddChildScreen(
              childData: state.extra as Map<String, dynamic>?,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/crear-hijo',
        builder: (context, state) => PrivacyAccessGate(
          child: LinkAccessGate(
            allowWhenNoChildren: true,
            child: const CrearHijoScreen(),
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
              ? (extra['childName'] ?? 'Menor').toString()
              : (extra as String? ?? 'Menor');

          return _protected(
            HomeScreen(
              childId: childId,
              childName: childName,
              tutorId: auth.currentUser?.uid ?? '',
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
                return _protected(
                  FiltersScreen(childId: childId, tutorId: tutorId),
                );
              case 'alerts':
                return _protected(
                  AlertsScreen(childId: childId, tutorId: tutorId),
                );
              case 'reports':
                return _protected(
                  ReportsScreen(childId: childId, tutorId: tutorId),
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
