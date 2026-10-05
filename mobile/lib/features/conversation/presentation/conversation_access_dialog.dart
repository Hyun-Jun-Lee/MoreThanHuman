import 'package:curitalk/core/copy/copy.dart';
import 'dart:io';
import 'package:curitalk/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> showConversationAccessDialog(BuildContext context) {
  final copy = AppCopy.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      alignment: const Alignment(0, -0.45),
      title: Text(copy.additionalConversationLabel),
      content: Text(copy.additionalConversationLocked),
      actions: [
        if (Platform.isIOS)
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push(AppRoute.paywall);
            },
            child: Text(copy.subscriptionTitle),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(copy.accessDialogConfirm),
        ),
      ],
    ),
  );
}
