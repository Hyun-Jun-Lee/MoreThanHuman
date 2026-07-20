import 'package:curitalk/features/roleplay_setup/domain/roleplay_difficulty.dart';
import 'package:curitalk/features/roleplay_setup/domain/roleplay_scenario.dart';
import 'package:curitalk/features/roleplay_setup/domain/roleplay_setup_payload.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoleplaySetupState {
  const RoleplaySetupState({
    this.selectedScenario,
    this.customInput = '',
    this.isCustomMode = false,
    this.difficulty = RoleplayDifficulty.normal,
  });

  final RoleplayScenario? selectedScenario;
  final String customInput;
  final bool isCustomMode;
  final RoleplayDifficulty difficulty;

  String get normalizedCustomInput => customInput.trim();
  bool get hasValidCustomInput => normalizedCustomInput.length >= 2;
  bool get hasSituation =>
      selectedScenario != null || (isCustomMode && hasValidCustomInput);
  bool get canStart => hasSituation;

  RoleplaySetupPayload? get payload {
    if (selectedScenario != null) {
      return RoleplaySetupPayload(
        situation: PresetRoleplaySituation(selectedScenario!),
        difficulty: difficulty,
      );
    }
    if (isCustomMode && hasValidCustomInput) {
      return RoleplaySetupPayload(
        situation: CustomRoleplaySituation(normalizedCustomInput),
        difficulty: difficulty,
      );
    }
    return null;
  }

  String? get customErrorText {
    if (!isCustomMode ||
        normalizedCustomInput.isEmpty ||
        normalizedCustomInput.length >= 2) {
      return null;
    }
    return 'Enter at least 2 characters.';
  }

  RoleplaySetupState copyWith({
    RoleplayScenario? selectedScenario,
    bool clearSelectedScenario = false,
    String? customInput,
    bool? isCustomMode,
    RoleplayDifficulty? difficulty,
  }) {
    return RoleplaySetupState(
      selectedScenario: clearSelectedScenario
          ? null
          : selectedScenario ?? this.selectedScenario,
      customInput: customInput ?? this.customInput,
      isCustomMode: isCustomMode ?? this.isCustomMode,
      difficulty: difficulty ?? this.difficulty,
    );
  }
}

class RoleplaySetupController extends Notifier<RoleplaySetupState> {
  @override
  RoleplaySetupState build() {
    return const RoleplaySetupState();
  }

  void selectScenario(RoleplayScenario scenario) {
    state = state.copyWith(selectedScenario: scenario, isCustomMode: false);
  }

  void enableCustomMode() {
    state = state.copyWith(clearSelectedScenario: true, isCustomMode: true);
  }

  void updateCustomInput(String input) {
    state = state.copyWith(customInput: input);
  }

  void selectDifficulty(RoleplayDifficulty difficulty) {
    state = state.copyWith(difficulty: difficulty);
  }

  RoleplaySetupPayload? prepareStart() {
    return state.payload;
  }
}

final roleplaySetupControllerProvider =
    NotifierProvider<RoleplaySetupController, RoleplaySetupState>(
      RoleplaySetupController.new,
    );
