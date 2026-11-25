import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/notifications/badge_sync_controller.dart';
import 'package:curitalk/core/notifications/ios_badge_bridge.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showBadgeChoice(BuildContext context, WidgetRef ref) async {
  final session = ref.read(authControllerProvider).value;
  if (session?.isMember != true) return;
  final account = session!.user!.id;
  final manager = ref.read(badgeSyncControllerProvider);
  final permission = await ref.read(iosBadgeBridgeProvider).permission();
  if (!context.mounted ||
      permission == BadgePermission.unsupported ||
      ref.read(authControllerProvider).value?.user?.id != account) {
    return;
  }
  final copy = AppCopy.of(context);
  final enabled = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(copy.badgeTitle),
      content: Text(copy.badgeExplanation),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(copy.badgeSkip),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(copy.badgeEnable),
        ),
      ],
    ),
  );
  if (!context.mounted ||
      enabled == null ||
      ref.read(authControllerProvider).value?.user?.id != account ||
      ref.read(authControllerProvider).value?.isMember != true) {
    return;
  }
  try {
    final result = await manager.choose(enabled);
    if (context.mounted && enabled && result == BadgePermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(copy.badgeSettingsMessage),
          action: SnackBarAction(
            label: copy.badgeSettings,
            onPressed: () async {
              try {
                await ref.read(iosBadgeBridgeProvider).openSettings();
              } catch (_) {}
            },
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.badgeSaveFailed)));
    }
  }
}

class BadgeSettingsButton extends ConsumerWidget {
  const BadgeSettingsButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authControllerProvider).value?.isMember != true) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<BadgePermission>(
      future: ref.watch(iosBadgeBridgeProvider).permission(),
      builder: (context, snapshot) =>
          snapshot.hasData && snapshot.data != BadgePermission.unsupported
          ? TextButton(
              onPressed: () => showBadgeChoice(context, ref),
              child: Text(AppCopy.of(context).badgeTitle),
            )
          : const SizedBox.shrink(),
    );
  }
}
