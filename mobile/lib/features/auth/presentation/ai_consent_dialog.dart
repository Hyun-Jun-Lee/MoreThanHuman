import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/auth/application/ai_consent_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AIConsentGate =
    Future<bool> Function(BuildContext context, WidgetRef ref);

final aiConsentGateProvider = Provider<AIConsentGate>((ref) => ensureAIConsent);

Future<bool> ensureAIConsent(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(aiConsentControllerProvider.notifier);
  final status = await controller.load();
  if (status.accepted) return true;
  if (!context.mounted) return false;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final copy = AppCopy.of(dialogContext);
      final privacyPolicyUrl = status.privacyPolicyUrlFor(
        isKorean: copy.isKorean,
      );
      return AlertDialog(
        title: Text(copy.aiConsentTitle),
        content: Text(copy.aiConsentDescription),
        actions: <Widget>[
          TextButton(
            onPressed: privacyPolicyUrl.isEmpty
                ? null
                : () => launchUrl(
                    Uri.parse(privacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
            child: Text(copy.privacyPolicyLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.agreeAndContinueLabel),
          ),
        ],
      );
    },
  );
  if (accepted != true) return false;
  return (await controller.accept()).accepted;
}
