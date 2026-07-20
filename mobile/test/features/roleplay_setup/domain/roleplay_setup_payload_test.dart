import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines the seven planned preset scenarios', () {
    expect(
      roleplayPresetScenarios.map(
        (RoleplayScenario scenario) => scenario.title,
      ),
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

  test('builds a backend-ready role character from a preset scenario', () {
    final RoleplaySetupPayload payload = RoleplaySetupPayload(
      situation: PresetRoleplaySituation(roleplayPresetScenarios.first),
      difficulty: RoleplayDifficulty.normal,
    );

    expect(payload.isValid, isTrue);
    expect(
      payload.roleCharacter,
      contains('a friendly cafe barista taking an order'),
    );
    expect(payload.roleCharacter, contains('natural and everyday'));
  });

  test('adds easy difficulty instructions to the role character', () {
    final RoleplaySetupPayload payload = RoleplaySetupPayload(
      situation: PresetRoleplaySituation(roleplayPresetScenarios.first),
      difficulty: RoleplayDifficulty.easy,
    );

    expect(payload.roleCharacter, contains('short, simple questions'));
    expect(payload.roleCharacter, contains('gentle'));
  });

  test('adds challenge difficulty instructions to the role character', () {
    final RoleplaySetupPayload payload = RoleplaySetupPayload(
      situation: PresetRoleplaySituation(roleplayPresetScenarios.first),
      difficulty: RoleplayDifficulty.challenge,
    );

    expect(payload.roleCharacter, contains('unexpected follow-up questions'));
    expect(payload.roleCharacter, contains('longer answers'));
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
      situation: CustomRoleplaySituation("i'm working on cafe as a barista"),
      difficulty: RoleplayDifficulty.normal,
    );

    expect(payload.roleCharacter, contains('play a customer'));
    expect(payload.roleCharacter, isNot(contains('play the learner')));
  });
}
