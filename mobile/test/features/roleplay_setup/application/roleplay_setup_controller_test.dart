import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with no situation and Normal difficulty', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final RoleplaySetupState state = container.read(
      roleplaySetupControllerProvider,
    );

    expect(state.selectedScenario, isNull);
    expect(state.isCustomMode, isFalse);
    expect(state.difficulty, RoleplayDifficulty.normal);
    expect(state.canStart, isFalse);
  });

  test('selecting a preset clears custom mode and enables start', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RoleplaySetupController controller = container.read(
      roleplaySetupControllerProvider.notifier,
    );

    controller.enableCustomMode();
    controller.updateCustomInput('오사카 식당 예약 확인');
    controller.selectScenario(enRoleplayScenarios.first);
    final RoleplaySetupState state = container.read(
      roleplaySetupControllerProvider,
    );

    expect(state.selectedScenario, enRoleplayScenarios.first);
    expect(state.isCustomMode, isFalse);
    expect(state.canStart, isTrue);
  });

  test('custom mode clears preset selection and validates input length', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RoleplaySetupController controller = container.read(
      roleplaySetupControllerProvider.notifier,
    );

    controller.selectScenario(enRoleplayScenarios.first);
    controller.enableCustomMode();
    controller.updateCustomInput('A');
    RoleplaySetupState state = container.read(roleplaySetupControllerProvider);

    expect(state.selectedScenario, isNull);
    expect(state.isCustomMode, isTrue);
    expect(state.canStart, isFalse);
    expect(state.customErrorText, 'Enter at least 2 characters.');

    controller.updateCustomInput('오사카 식당 예약 확인');
    state = container.read(roleplaySetupControllerProvider);

    expect(state.canStart, isTrue);
    expect(state.customErrorText, isNull);
    expect(state.payload?.roleCharacter, contains('오사카 식당 예약 확인'));
  });

  test('difficulty changes are reflected in payload', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RoleplaySetupController controller = container.read(
      roleplaySetupControllerProvider.notifier,
    );

    controller.selectScenario(enRoleplayScenarios.first);
    controller.selectDifficulty(RoleplayDifficulty.challenge);
    final RoleplaySetupState state = container.read(
      roleplaySetupControllerProvider,
    );

    expect(state.difficulty, RoleplayDifficulty.challenge);
    expect(state.payload?.roleCharacter, contains('unexpected'));
    expect(state.payload?.roleCharacter, contains('more precise answers'));
  });
}
