import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showAccountSheet({
  required BuildContext context,
  required WidgetRef ref,
  required UserProfile? user,
}) {
  return showAppModalSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      bool isLoggingOut = false;
      final String name = user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : 'Curitalk user';
      final String email = user?.email.trim() ?? '';

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AppSectionLabel('Account'),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: AppSize.iconButton / 2,
                    backgroundColor: AppPalette.blockPink,
                    child: Text(_initialFor(name), style: AppTypography.button),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name, style: AppTypography.headlineMd),
                        if (email.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            email,
                            style: AppTypography.bodySm.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: 'LOG OUT',
                isLoading: isLoggingOut,
                onPressed: isLoggingOut
                    ? null
                    : () async {
                        setSheetState(() => isLoggingOut = true);
                        await _signOutGoogleSafely(ref);
                        await ref
                            .read(authControllerProvider.notifier)
                            .logout();
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: isLoggingOut
                    ? null
                    : () => Navigator.pop(sheetContext),
                child: const Text('CANCEL'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _initialFor(String name) {
  final String normalized = name.trim();
  if (normalized.isEmpty) {
    return '?';
  }
  return normalized.characters.first.toUpperCase();
}

Future<void> _signOutGoogleSafely(WidgetRef ref) async {
  try {
    await ref.read(googleIdentityServiceProvider).signOut();
  } on Object {
    return;
  }
}
