import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'theme_notifier.dart';
import 'theme/vesta_theme.dart';
import 'package:vesta_app/firebase_options.dart';
import 'package:vesta_app/core/router/app_router.dart';
import 'package:vesta_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Error al inicializar Firebase: $e");
  }

  final appRouter = AppRouter();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: MyApp(router: appRouter.router),
    ),
  );

  unawaited(_inicializarNotificaciones());
}

Future<void> _inicializarNotificaciones() async {
  try {
    final notificationService = NotificationService();
    await notificationService.inicializarNotificaciones();
  } catch (e, stackTrace) {
    debugPrint('Error al inicializar notificaciones: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class MyApp extends StatelessWidget {
  final GoRouter router;

  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp.router(
      title: 'VESTA - Panel de Control Parental',
      debugShowCheckedModeBanner: false,
      theme: VestaTheme.lightTheme,
      darkTheme: VestaTheme.darkTheme,
      themeMode: themeNotifier.themeMode,
      routerConfig: router,
    );
  }
}
