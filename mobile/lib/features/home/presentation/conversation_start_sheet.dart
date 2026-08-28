import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/home/domain/conversation_start_type.dart';
import 'package:flutter/material.dart';

Future<ConversationStartType?> showConversationStartSheet(
  BuildContext context,
) {
  return showAppModalSheet<ConversationStartType>(
    context: context,
    builder: (BuildContext sheetContext) {
      final AppCopy copy = AppCopy.of(sheetContext);
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
          Text(copy.startConversationTitle, style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.lg),
          AppSelectionCard(
            title: copy.freeChatTitle,
            description: copy.freeChatDescription,
            icon: const Icon(Icons.forum_outlined),
            selected: false,
            onTap: () =>
                Navigator.pop(sheetContext, ConversationStartType.freeChat),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSelectionCard(
            title: copy.roleplayTitle,
            description: copy.roleplayDescription,
            icon: const Icon(Icons.theater_comedy_outlined),
            selected: false,
            onTap: () =>
                Navigator.pop(sheetContext, ConversationStartType.roleplay),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(copy.cancelLabel),
          ),
        ],
      );
    },
  );
}
