import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/language/language.dart';
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
      bool isSavingLanguage = false;
      String? languageError;
      LearningLanguageContext selectedLanguage =
          user?.language ?? LearningLanguageContext.defaultContext;
      final String name = user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : 'Curitalk user';
      final String email = user?.email.trim() ?? '';

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          final String localeCode = Localizations.localeOf(
            context,
          ).languageCode;
          return SingleChildScrollView(
            child: Column(
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
                      child: Text(
                        _initialFor(name),
                        style: AppTypography.button,
                      ),
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
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.xl),
                const AppSectionLabel('Language Pair'),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  selectedLanguage.preferenceChangePolicyText(localeCode),
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                LanguagePairSelector(
                  selected: selectedLanguage,
                  onChanged: (LearningLanguageContext next) {
                    setSheetState(() {
                      selectedLanguage = next;
                      languageError = null;
                    });
                  },
                  localeCode: localeCode,
                  enabled: !isSavingLanguage && !isLoggingOut,
                ),
                if (languageError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      languageError!,
                      style: AppTypography.bodySm.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: 'SAVE LANGUAGE PAIR',
                  isLoading: isSavingLanguage,
                  onPressed:
                      isLoggingOut ||
                          isSavingLanguage ||
                          selectedLanguage ==
                              (user?.language ??
                                  LearningLanguageContext.defaultContext)
                      ? null
                      : () async {
                          setSheetState(() {
                            isSavingLanguage = true;
                            languageError = null;
                          });
                          try {
                            await ref
                                .read(languagePreferencesRepositoryProvider)
                                .updateLanguagePreferences(selectedLanguage);
                            ref.invalidate(
                              languagePreferencesControllerProvider,
                            );
                            await ref
                                .read(authControllerProvider.notifier)
                                .restoreSession();
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          } on Object {
                            if (sheetContext.mounted) {
                              setSheetState(() {
                                languageError =
                                    'Language pair could not be saved.';
                              });
                            }
                          } finally {
                            if (sheetContext.mounted) {
                              setSheetState(() => isSavingLanguage = false);
                            }
                          }
                        },
                ),
              ],
            ),
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
