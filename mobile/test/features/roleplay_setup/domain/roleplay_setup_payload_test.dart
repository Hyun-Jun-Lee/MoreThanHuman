import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines the seven planned preset scenarios', () {
    expect(
      enRoleplayScenarios.map((RoleplayScenario scenario) => scenario.title),
      <String>[
        'Cafe order',
        'Hotel check-in',
        'Airport immigration',
        'Job interview',
        'Meeting small talk',
        'Friend conversation',
        'Meeting opinion',
      ],
    );
  });

  test('defines Korean-practice preset scenarios for Korean target', () {
    expect(
      roleplayPresetScenariosFor(
        LearningLanguageCode.ko,
      ).map((RoleplayScenario scenario) => scenario.title),
      containsAll(<String>[
        'Polite cafe order',
        'Self-introduction',
        'Workplace greeting',
        'Clinic visit',
      ]),
    );
  });

  test('builds backend-ready role character from a preset scenario', () {
    final RoleplaySetupPayload payload = RoleplaySetupPayload(
      situation: PresetRoleplaySituation(enRoleplayScenarios.first),
    );

    expect(payload.isValid, isTrue);
    expect(
      payload.roleCharacter,
      contains('a friendly cafe barista taking an order'),
    );
    expect(payload.roleCharacter, isNot(contains('everyday pacing')));
  });

  test('trims custom situations and validates minimum length', () {
    const CustomRoleplaySituation valid = CustomRoleplaySituation(
      '  오사카 식당에서 예약 확인하기  ',
    );
    const CustomRoleplaySituation invalid = CustomRoleplaySituation(' A ');

    expect(valid.isValid, isTrue);
    expect(valid.displayText, '오사카 식당에서 예약 확인하기');
    expect(valid.promptBase, contains('learner-defined roleplay'));
    expect(valid.promptBase, contains('opposite role'));
    expect(invalid.isValid, isFalse);
  });

  test('custom roleplay treats learner role as the counterpart target', () {
    const RoleplaySetupPayload payload = RoleplaySetupPayload(
      situation: CustomRoleplaySituation("I'm a hotel guest asking for help"),
    );

    expect(payload.roleCharacter, contains('play the front desk staff member'));
    expect(payload.roleCharacter, isNot(contains('play the learner')));
  });
}
