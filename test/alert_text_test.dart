import 'package:flutter_test/flutter_test.dart';
import 'package:vesta_app/l10n/alert_text.dart';

void main() {
  test('rebuilds a Spanish tracker alert in English', () {
    final text = AlertText.of({
      'eventKey': 'zone_enter',
      'zoneName': 'Colegio',
      'title': 'Llegó a Colegio',
      'subtitle': 'El dispositivo entró en la zona segura "Colegio".',
    }, lang: 'en');
    expect(text.title, 'Arrived at Colegio');
    expect(text.body, 'The device entered the safe zone "Colegio".');
  });

  test('rebuilds an English tracker alert in Spanish', () {
    final text = AlertText.of({
      'eventKey': 'blocked_app',
      'title': 'App blocked',
      'subtitle': 'Tried to open: Roblox',
    }, lang: 'es');
    expect(text.title, 'Aplicación bloqueada');
    expect(text.body, 'Intentó abrir: Roblox');
  });

  test('server offline alert and battery level', () {
    expect(
      AlertText.of({'eventKey': 'device_offline', 'offlineMinutes': 150}, lang: 'en').body,
      startsWith('Vesta Tracker has not sent data for 2.5 hours.'),
    );
    expect(
      AlertText.of({'eventKey': 'battery_low', 'subtitle': 'La batería del dispositivo está al 18%.'}, lang: 'en').body,
      'The device battery is at 18%.',
    );
  });

  test('keeps the stored text for unknown events or missing values', () {
    final unknown = AlertText.of({'eventKey': 'future', 'title': 'Algo', 'subtitle': 'Detalle'}, lang: 'en');
    expect(unknown.title, 'Algo');
    expect(unknown.body, 'Detalle');
    final noZone = AlertText.of({'eventKey': 'zone_exit', 'title': 'Salió', 'subtitle': 'x'}, lang: 'en');
    expect(noZone.title, 'Salió');
  });

  test('formatMinutes', () {
    expect(AlertText.formatMinutes(1, 'es'), '1 minuto');
    expect(AlertText.formatMinutes(45, 'en'), '45 minutes');
    expect(AlertText.formatMinutes(180, 'es'), '3 horas');
  });
}
