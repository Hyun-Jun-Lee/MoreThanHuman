import 'package:curitalk/core/storage/storage_providers.dart';
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

typedef BadgeSettingsBuilder =
    Widget Function(
      BuildContext context,
      bool enabled,
      ValueChanged<bool>? onChanged,
    );

class BadgeSettingsButton extends ConsumerStatefulWidget {
  const BadgeSettingsButton({this.builder, super.key});
  final BadgeSettingsBuilder? builder;
  @override
  ConsumerState<BadgeSettingsButton> createState() =>
      _BadgeSettingsButtonState();
}

class _BadgeSettingsButtonState extends ConsumerState<BadgeSettingsButton>
    with WidgetsBindingObserver {
  String? _account;
  Future<(BadgePermission, bool)>? _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<(BadgePermission, bool)> _load(String account) async {
    final bridge = ref.read(iosBadgeBridgeProvider);
    final storage = ref.read(secureStorageBackendProvider);
    final permission = await bridge.permission();
    if (permission == BadgePermission.unsupported) return (permission, false);
    final choice = await storage.read('badge.choice.$account');
    return (
      permission,
      choice == 'enabled' && permission == BadgePermission.allowed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _account != null) {
      setState(() => _settings = _load(_account!));
    }
  }

  Future<void> _choose(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final account = _account;
      final result = await ref
          .read(badgeSyncControllerProvider)
          .choose(enabled);
      if (mounted &&
          enabled &&
          result == BadgePermission.denied &&
          ref.read(authControllerProvider).value?.user?.id == account) {
        final copy = AppCopy.of(context);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppCopy.of(context).badgeSaveFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          if (_account != null) _settings = _load(_account!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).value;
    if (session?.isMember != true) {
      _account = null;
      _settings = null;
      return const SizedBox.shrink();
    }
    if (_account != session!.user!.id) {
      _account = session.user!.id;
      _settings = _load(_account!);
    }
    return FutureBuilder<(BadgePermission, bool)>(
      future: _settings,
      builder: (context, snapshot) {
        if (!snapshot.hasData ||
            snapshot.data!.$1 == BadgePermission.unsupported) {
          return const SizedBox.shrink();
        }
        if (widget.builder != null) {
          return widget.builder!(
            context,
            snapshot.data!.$2,
            _saving ? null : _choose,
          );
        }
        return TextButton(
          onPressed: _saving ? null : () => _choose(true),
          child: Text(AppCopy.of(context).badgeTitle),
        );
      },
    );
  }
}
