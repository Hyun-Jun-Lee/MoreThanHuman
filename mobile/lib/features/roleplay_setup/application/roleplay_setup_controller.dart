import 'package:curitalk/features/roleplay_setup/domain/roleplay_scenario.dart';
import 'package:curitalk/features/roleplay_setup/domain/roleplay_setup_payload.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RoleplaySetupValidationReason { customInputTooShort }

class RoleplaySetupState {
  const RoleplaySetupState({
    this.selectedScenario,
    this.customInput = '',
    this.isCustomMode = false,
  });

  final RoleplayScenario? selectedScenario;
  final String customInput;
  final bool isCustomMode;

  String get normalizedCustomInput => customInput.trim();
  bool get hasValidCustomInput => normalizedCustomInput.length >= 2;
  bool get hasSituation =>
      selectedScenario != null || (isCustomMode && hasValidCustomInput);
  bool get canStart => hasSituation;

  RoleplaySetupPayload? get payload {
    if (selectedScenario != null) {
      return RoleplaySetupPayload(
        situation: PresetRoleplaySituation(selectedScenario!),
      );
    }
    if (isCustomMode && hasValidCustomInput) {
      return RoleplaySetupPayload(
        situation: CustomRoleplaySituation(normalizedCustomInput),
      );
    }
    return null;
  }

  RoleplaySetupValidationReason? get customValidationReason {
    if (!isCustomMode ||
        normalizedCustomInput.isEmpty ||
        normalizedCustomInput.length >= 2) {
      return null;
    }
    return RoleplaySetupValidationReason.customInputTooShort;
  }

  RoleplaySetupState copyWith({
    RoleplayScenario? selectedScenario,
    bool clearSelectedScenario = false,
    String? customInput,
    bool? isCustomMode,
  }) {
    return RoleplaySetupState(
      selectedScenario: clearSelectedScenario
          ? null
          : selectedScenario ?? this.selectedScenario,
      customInput: customInput ?? this.customInput,
      isCustomMode: isCustomMode ?? this.isCustomMode,
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

  RoleplaySetupPayload? prepareStart() {
    return state.payload;
  }
}

final roleplaySetupControllerProvider =
    NotifierProvider<RoleplaySetupController, RoleplaySetupState>(
      RoleplaySetupController.new,
    );
