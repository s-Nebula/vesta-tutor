import 'package:flutter_test/flutter_test.dart';
import 'package:vesta_app/services/study_mode_config.dart';
import 'package:vesta_app/l10n/tr.dart';

void main() {
  // The tests check the Spanish texts.
  setUpAll(() => debugSetAppLanguage('es'));

  // 2026-11-23 is a Monday.
  final monday1700 = DateTime(2026, 11, 23, 17, 0);

  test('lee el documento y calcula el horario activo', () {
    final config = StudyModeConfig.fromDoc({
      'active': false,
      'endsAt': null,
      'allowedApps': ['com.example.calc'],
      'schedules': [
        {'days': [1, 2, 3, 4, 5], 'start': '16:00', 'end': '18:00'},
        {'days': [9], 'start': '10:00', 'end': '11:00'}, // invalid
      ],
    });

    expect(config.schedules, hasLength(1));
    expect(config.schedules.first.label, 'Lunes a viernes · 16:00 – 18:00');
    expect(config.isActiveAt(monday1700), isTrue);
    expect(config.currentEnd(monday1700), DateTime(2026, 11, 23, 18));
    expect(config.isActiveAt(DateTime(2026, 11, 28, 17)), isFalse);
  });

  test('franja nocturna', () {
    const schedule = StudySchedule(days: [7], start: '21:00', end: '07:00');
    expect(schedule.activeEnd(DateTime(2026, 11, 22, 22)),
        DateTime(2026, 11, 23, 7));
    expect(schedule.activeEnd(DateTime(2026, 11, 23, 6, 59)),
        DateTime(2026, 11, 23, 7));
    expect(schedule.activeEnd(DateTime(2026, 11, 23, 7)), isNull);
  });

  test('activación manual con caducidad', () {
    final config = StudyModeConfig(
      active: true,
      endsAt: monday1700.add(const Duration(hours: 1)),
    );
    expect(config.isActiveAt(monday1700), isTrue);
    expect(config.isActiveAt(monday1700.add(const Duration(hours: 2))), isFalse);
    expect(const StudyModeConfig(active: true).currentEnd(monday1700), isNull);
  });
}
