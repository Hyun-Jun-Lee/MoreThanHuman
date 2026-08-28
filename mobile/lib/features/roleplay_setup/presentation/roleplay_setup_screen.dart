import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
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
    final AppCopy copy = AppCopy.of(context);
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
      appBar: AppBar(title: Text(copy.roleplayTitle)),
      bottomNavigationBar: AppBottomActionBar(
        child: AppPrimaryButton(
          label: copy.startRoleplayLabel,
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
            copy.chooseSituationTitle,
            style: AppTypography.headlineLg.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.chooseSituationDescription,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionLabel(copy.chooseDifficultyLabel),
          const SizedBox(height: AppSpacing.md),
          _RoleplayDifficultySelector(
            selected: state.difficulty,
            onSelected: controller.selectDifficulty,
          ),
          if (startState.failureReason != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              copy.failureMessage(startState.failureReason!.name),
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
          AppSectionLabel(copy.differentSituationLabel),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              controller.enableCustomMode();
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(copy.customRoleplayLabel),
          ),
          if (state.isCustomMode) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _customController,
              hintText: roleplayCustomSituationHintFor(targetLanguage),
              errorText: state.customValidationReason == null
                  ? null
                  : copy.customRoleplayInputTooShort,
              autofocus: state.customInput.isEmpty,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              semanticLabel: copy.customRoleplaySemanticLabel,
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
    final AppCopy copy = AppCopy.of(context);
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
                    label: copy.roleplayDifficultyLabel(difficulty.apiValue),
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
          copy.roleplayDifficultyDescription(selected.apiValue),
          style: AppTypography.bodySm.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
