import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> showConversationAccessDialog(
  BuildContext context, {
  bool guestLimit = false,
  String purpose = 'buy_slots',
}) {
  final copy = AppCopy.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      alignment: const Alignment(0, -0.45),
      title: Text(
        guestLimit
            ? copy.signInToContinueLabel
            : purpose == 'buy_turns'
            ? (copy.isKorean ? '대화권 충전' : 'Conversation credits')
            : copy.additionalConversationLabel,
      ),
      content: Text(
        guestLimit
            ? copy.guestTurnLimitReached
            : purpose == 'buy_turns'
            ? copy.conversationTurnLimitReached
            : copy.additionalConversationLocked,
      ),
      actions: [
        if (guestLimit)
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push(AppRoute.login);
            },
            child: Text(copy.signInToContinueLabel),
          ),
        if (!guestLimit &&
            Theme.of(dialogContext).platform == TargetPlatform.iOS)
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('${AppRoute.paywall}?purpose=$purpose');
            },
            child: Text(copy.subscriptionDialogActionLabel),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(copy.accessDialogConfirm),
        ),
      ],
    ),
  );
}
