import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

Future<void> showConversationAccessDialog(BuildContext context) {
  final copy = AppCopy.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(copy.additionalConversationLabel),
      content: Text(copy.additionalConversationLocked),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(copy.accessDialogConfirm),
        ),
      ],
    ),
  );
}
