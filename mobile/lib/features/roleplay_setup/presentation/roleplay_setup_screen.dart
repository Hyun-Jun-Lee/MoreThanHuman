import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                      .startRoleplay(roleCharacter: payload.roleCharacter);
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
          for (final RoleplayScenario scenario in roleplayPresetScenarios) ...[
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
              hintText: '오사카 식당에서 예약 확인하기',
              errorText: state.customErrorText,
              autofocus: state.customInput.isEmpty,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              semanticLabel: 'Custom roleplay situation',
              onChanged: controller.updateCustomInput,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const AppSectionLabel('Choose difficulty'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              for (final RoleplayDifficulty difficulty
                  in RoleplayDifficulty.values)
                RoleplayDifficultyChip(
                  difficulty: difficulty,
                  selected: state.difficulty == difficulty,
                  onSelected: () => controller.selectDifficulty(difficulty),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }
}
