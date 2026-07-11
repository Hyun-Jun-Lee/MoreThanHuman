import 'package:curitalk/features/roleplay_setup/domain/roleplay_difficulty.dart';
import 'package:curitalk/features/roleplay_setup/domain/roleplay_scenario.dart';

sealed class RoleplaySituation {
  const RoleplaySituation();

  String get displayText;
  String get promptBase;
  bool get isValid;
}

class PresetRoleplaySituation extends RoleplaySituation {
  const PresetRoleplaySituation(this.scenario);

  final RoleplayScenario scenario;

  @override
  String get displayText => scenario.title;

  @override
  String get promptBase => scenario.roleCharacter;

  @override
  bool get isValid => true;
}

class CustomRoleplaySituation extends RoleplaySituation {
  const CustomRoleplaySituation(this.input);

  final String input;

  String get normalizedInput => input.trim();

  @override
  String get displayText => normalizedInput;

  @override
  String get promptBase {
    return 'a realistic counterpart in a learner-defined roleplay where the learner described their situation or role as "$normalizedInput"; '
        'if the learner describes their own role, play the opposite role in that situation; '
        'for example, if the learner is working as a cafe barista, play a customer placing an order';
  }

  @override
  bool get isValid => normalizedInput.length >= 2;
}

class RoleplaySetupPayload {
  const RoleplaySetupPayload({
    required this.situation,
    required this.difficulty,
  });

  final RoleplaySituation situation;
  final RoleplayDifficulty difficulty;

  bool get isValid => situation.isValid;

  String get roleCharacter {
    return '${situation.promptBase} who ${difficulty.promptInstruction}';
  }
}
