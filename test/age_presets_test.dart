import 'package:flutter_test/flutter_test.dart';
import 'package:vesta_app/services/age_presets.dart';
import 'package:vesta_app/l10n/tr.dart';

void main() {
  // The tests check the Spanish texts.
  setUpAll(() => debugSetAppLanguage('es'));

  test('las restricciones disminuyen con la edad', () {
    final child = AgePresets.forAge(9);
    final teen = AgePresets.forAge(14);
    final older = AgePresets.forAge(17);
    final adult = AgePresets.forAge(19);

    expect(child.domains, containsAll(AgePresets.socialDomains));
    expect(child.apps, contains('com.instagram.android'));
    expect(teen.domains, isNot(contains('instagram.com')));
    expect(teen.domains, containsAll(AgePresets.strangerChat));
    expect(older.domains, isNot(contains('chatroulette.com')));
    expect(older.domains, containsAll(AgePresets.adult));
    expect(adult.isEmpty, isTrue);
    for (final preset in [child, teen, older]) {
      expect(preset.safeSearch, isTrue);
      expect(preset.domains.toSet().length, preset.domains.length);
    }
  });

  test('límites exactos de edad', () {
    expect(AgePresets.forAge(12).apps, isNotEmpty);
    expect(AgePresets.forAge(13).apps, isEmpty);
    expect(AgePresets.forAge(16).domains, isNot(contains('ome.tv')));
    expect(AgePresets.forAge(18).isEmpty, isTrue);
  });
}
