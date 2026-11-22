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
import 'package:vesta_app/widgets/offline_banner.dart';

import 'package:vesta_app/l10n/tr.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Error al inicializar Firebase: $e");
  }

  await LanguageNotifier.load();

  final appRouter = AppRouter();

  // Tapping a notice opens the matching screen for that minor.
  NotificationService.instance.setNavigationHandler((childId, kind) {
    final id = Uri.encodeComponent(childId);
    appRouter.router.go(switch (kind) {
      'request' => '/home/$id?open=requests',
      'weekly_summary' => '/home/$id?tab=reports',
      _ => '/home/$id?tab=alerts',
    });
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => LanguageNotifier()),
      ],
      child: MyApp(router: appRouter.router),
    ),
  );

  unawaited(_inicializarNotificaciones());
}

Future<void> _inicializarNotificaciones() async {
  try {
    await NotificationService.instance.inicializarNotificaciones();
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
    // Rebuild everything when the language changes.
    Provider.of<LanguageNotifier>(context);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = switch (themeNotifier.themeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => platformBrightness,
    };

    // VestaTheme's semantic colours depend on the mode; the whole tree is
    // rebuilt when it changes (the router keeps the current route).
    VestaTheme.applyBrightness(brightness);

    return MaterialApp.router(
      key: ValueKey('$brightness-$appLanguage'),
      title: tr('VESTA - Panel de Control Parental'),
      debugShowCheckedModeBanner: false,
      theme: VestaTheme.lightTheme,
      darkTheme: VestaTheme.darkTheme,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        // Honour the system text size, with a readable minimum.
        final media = MediaQuery.of(context);
        final scaler = media.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6);
        return MediaQuery(
          data: media.copyWith(textScaler: scaler),
          child: OfflineBanner(child: child ?? const SizedBox()),
        );
      },
    );
  }
}
