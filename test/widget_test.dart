import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vesta_app/main.dart';
import 'package:vesta_app/theme_notifier.dart';

void main() {
  testWidgets('La aplicación inicia y muestra su ruta inicial',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text('Ruta de inicio Vesta'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeNotifier(),
        child: MyApp(router: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ruta de inicio Vesta'), findsOneWidget);

    router.dispose();
  });
}
