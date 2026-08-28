import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

Future<bool> showConversationDeleteDialog({
  required BuildContext context,
  required String title,
}) async {
  final AppCopy copy = AppCopy.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(copy.deleteConversationTitle(title)),
          content: Text(copy.deleteConversationMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(copy.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(copy.deleteLabel),
            ),
          ],
        ),
      ) ??
      false;
}
