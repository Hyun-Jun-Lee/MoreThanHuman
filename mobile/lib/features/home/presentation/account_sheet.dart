import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
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
      bool isSavingAppLocale = false;
      String? languageError;
      String? appLocaleError;
      LearningLanguageContext selectedLanguage =
          user?.language ?? LearningLanguageContext.defaultContext;
      String selectedAppLocale =
          user?.appLocale ??
          (Localizations.localeOf(context).languageCode == 'ko' ? 'ko' : 'en');
      final String name = user?.name.trim().isNotEmpty == true
          ? user!.name.trim()
          : 'Curitalk user';
      final String email = user?.email.trim() ?? '';

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          final AppCopy copy = AppCopy.of(context);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppSectionLabel(copy.accountLabel),
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
                  label: copy.logOutLabel,
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
                AppSectionLabel(copy.appLanguageSectionLabel),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: <Widget>[
                    AppSelectionChip(
                      label: copy.appLanguageKoreanLabel,
                      selected: selectedAppLocale == 'ko',
                      onSelected: isSavingAppLocale || isLoggingOut
                          ? null
                          : (bool selected) {
                              if (selected) {
                                setSheetState(() {
                                  selectedAppLocale = 'ko';
                                  appLocaleError = null;
                                });
                              }
                            },
                    ),
                    AppSelectionChip(
                      label: copy.appLanguageEnglishLabel,
                      selected: selectedAppLocale == 'en',
                      onSelected: isSavingAppLocale || isLoggingOut
                          ? null
                          : (bool selected) {
                              if (selected) {
                                setSheetState(() {
                                  selectedAppLocale = 'en';
                                  appLocaleError = null;
                                });
                              }
                            },
                    ),
                  ],
                ),
                if (appLocaleError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    appLocaleError!,
                    style: AppTypography.bodySm.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppPrimaryButton(
                  label: copy.saveAppLanguageLabel,
                  isLoading: isSavingAppLocale,
                  onPressed:
                      isLoggingOut ||
                          isSavingAppLocale ||
                          selectedAppLocale == user?.appLocale
                      ? null
                      : () async {
                          setSheetState(() {
                            isSavingAppLocale = true;
                            appLocaleError = null;
                          });
                          try {
                            await ref
                                .read(authControllerProvider.notifier)
                                .updateAppLocale(selectedAppLocale);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          } on Object {
                            if (sheetContext.mounted) {
                              setSheetState(
                                () =>
                                    appLocaleError = copy.appLanguageSaveFailed,
                              );
                            }
                          } finally {
                            if (sheetContext.mounted) {
                              setSheetState(() => isSavingAppLocale = false);
                            }
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSectionLabel(copy.languagePairSectionLabel),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  copy.preferenceChangePolicyText(),
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
                  label: copy.saveLanguagePairLabel,
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
                                languageError = copy.languagePairSaveFailed;
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
