import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/home/domain/conversation_start_type.dart';
import 'package:flutter/material.dart';

Future<ConversationStartType?> showConversationStartSheet(
  BuildContext context,
) {
  return showAppModalSheet<ConversationStartType>(
    context: context,
    builder: (BuildContext sheetContext) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: AppSpacing.xxl,
              height: AppSpacing.xxs,
              decoration: const BoxDecoration(
                color: AppPalette.hairline,
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Start a conversation', style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.lg),
          AppSelectionCard(
            title: 'Free Chat',
            description: 'Bring your own topic',
            icon: const Icon(Icons.forum_outlined),
            selected: false,
            onTap: () =>
                Navigator.pop(sheetContext, ConversationStartType.freeChat),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSelectionCard(
            title: 'Roleplay',
            description: 'Practice a real-world situation',
            icon: const Icon(Icons.theater_comedy_outlined),
            selected: false,
            onTap: () =>
                Navigator.pop(sheetContext, ConversationStartType.roleplay),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('CANCEL'),
          ),
        ],
      );
    },
  );
}
