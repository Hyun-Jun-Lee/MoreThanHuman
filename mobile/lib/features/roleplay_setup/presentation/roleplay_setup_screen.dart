import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final roleplayTargetLanguageProvider = Provider<LearningLanguageCode>((
  Ref ref,
) {
  return ref.watch(
    authControllerProvider.select(
      (AsyncValue<AuthSession> auth) =>
          auth.value?.user?.language.targetLanguage ??
          LearningLanguageContext.defaultContext.targetLanguage,
    ),
  );
});

class RoleplaySetupScreen extends ConsumerStatefulWidget {
  const RoleplaySetupScreen({super.key});

  @override
  ConsumerState<RoleplaySetupScreen> createState() =>
      _RoleplaySetupScreenState();
}

class _RoleplaySetupScreenState extends ConsumerState<RoleplaySetupScreen> {
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RoleplaySetupState state = ref.watch(roleplaySetupControllerProvider);
    final LearningLanguageCode targetLanguage = ref.watch(
      roleplayTargetLanguageProvider,
    );
    final List<RoleplayScenario> scenarios = roleplayPresetScenariosFor(
      targetLanguage,
    );
    final StartConversationState startState = ref.watch(
      startConversationControllerProvider,
    );
    final RoleplaySetupController controller = ref.read(
      roleplaySetupControllerProvider.notifier,
    );

    return AppScaffold(
      appBar: AppBar(title: const Text('Roleplay')),
      bottomNavigationBar: AppBottomActionBar(
        child: AppPrimaryButton(
          label: 'START ROLEPLAY',
          isLoading: startState.isStarting,
          onPressed: state.canStart && !startState.isStarting
              ? () async {
                  final RoleplaySetupPayload? payload = controller
                      .prepareStart();
                  if (payload == null) {
                    return;
                  }
                  final ConversationResponse? response = await ref
                      .read(startConversationControllerProvider.notifier)
                      .startRoleplay(
                        roleCharacter: payload.roleCharacter,
                        roleplayDifficulty: payload.roleplayDifficultyValue,
                      );
                  if (!context.mounted || response == null) {
                    return;
                  }
                  context.go(
                    AppRoute.conversationPath(response.conversationId),
                  );
                }
              : null,
        ),
      ),
      body: ListView(
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Choose a situation',
            style: AppTypography.headlineLg.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Pick a real-world moment to practice, or write your own custom roleplay.',
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionLabel('Choose difficulty'),
          const SizedBox(height: AppSpacing.md),
          _RoleplayDifficultySelector(
            selected: state.difficulty,
            onSelected: controller.selectDifficulty,
          ),
          if (startState.errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              startState.errorMessage!,
              style: AppTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          for (final RoleplayScenario scenario in scenarios) ...[
            RoleplayScenarioCard(
              scenario: scenario,
              selected: state.selectedScenario?.id == scenario.id,
              onTap: () {
                controller.selectScenario(scenario);
                FocusScope.of(context).unfocus();
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          const AppSectionLabel('Want a different situation?'),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              controller.enableCustomMode();
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('CUSTOM ROLEPLAY'),
          ),
          if (state.isCustomMode) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _customController,
              hintText: roleplayCustomSituationHintFor(targetLanguage),
              errorText: state.customErrorText,
              autofocus: state.customInput.isEmpty,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              semanticLabel: 'Custom roleplay situation or your role',
              onChanged: controller.updateCustomInput,
            ),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }
}

class _RoleplayDifficultySelector extends StatelessWidget {
  const _RoleplayDifficultySelector({
    required this.selected,
    required this.onSelected,
  });

  final RoleplayDifficulty selected;
  final ValueChanged<RoleplayDifficulty> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final RoleplayDifficulty difficulty
                in RoleplayDifficulty.values) ...<Widget>[
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppSelectionChip(
                    label: difficulty.label,
                    selected: selected == difficulty,
                    onSelected: (_) => onSelected(difficulty),
                  ),
                ),
              ),
              if (difficulty != RoleplayDifficulty.values.last)
                const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          selected.description,
          style: AppTypography.bodySm.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
