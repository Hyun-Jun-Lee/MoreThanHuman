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
      final LearningLanguageContext selectedLanguage =
          user?.language ?? LearningLanguageContext.defaultContext;
      final String selectedAppLocale =
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
                          : (_) async {
                              await _changeAppLocale(
                                context: context,
                                sheetContext: sheetContext,
                                ref: ref,
                                copy: copy,
                                user: user,
                                nextLocale: 'ko',
                                setSheetState: setSheetState,
                                setSaving: (bool value) =>
                                    isSavingAppLocale = value,
                                setError: (String? value) =>
                                    appLocaleError = value,
                              );
                            },
                    ),
                    AppSelectionChip(
                      label: copy.appLanguageEnglishLabel,
                      selected: selectedAppLocale == 'en',
                      onSelected: isSavingAppLocale || isLoggingOut
                          ? null
                          : (_) async {
                              await _changeAppLocale(
                                context: context,
                                sheetContext: sheetContext,
                                ref: ref,
                                copy: copy,
                                user: user,
                                nextLocale: 'en',
                                setSheetState: setSheetState,
                                setSaving: (bool value) =>
                                    isSavingAppLocale = value,
                                setError: (String? value) =>
                                    appLocaleError = value,
                              );
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
                if (isSavingAppLocale)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
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
                  onChanged: (LearningLanguageContext next) async {
                    await _changeLanguagePair(
                      context: context,
                      sheetContext: sheetContext,
                      ref: ref,
                      copy: copy,
                      currentLanguage: selectedLanguage,
                      nextLanguage: next,
                      setSheetState: setSheetState,
                      setSaving: (bool value) => isSavingLanguage = value,
                      setError: (String? value) => languageError = value,
                    );
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
                if (isSavingLanguage)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _changeAppLocale({
  required BuildContext context,
  required BuildContext sheetContext,
  required WidgetRef ref,
  required AppCopy copy,
  required UserProfile? user,
  required String nextLocale,
  required StateSetter setSheetState,
  required ValueChanged<bool> setSaving,
  required ValueChanged<String?> setError,
}) async {
  if (nextLocale == user?.appLocale) return;
  final bool confirmed = await _showPreferenceChangeDialog(
    context: context,
    copy: copy,
    message: copy.changeAppLanguageMessage(copy.languageName(nextLocale)),
  );
  if (!confirmed || !sheetContext.mounted) return;

  setSheetState(() {
    setSaving(true);
    setError(null);
  });
  try {
    await ref.read(authControllerProvider.notifier).updateAppLocale(nextLocale);
    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }
  } on Object {
    if (sheetContext.mounted) {
      setSheetState(() => setError(copy.appLanguageSaveFailed));
    }
  } finally {
    if (sheetContext.mounted) {
      setSheetState(() => setSaving(false));
    }
  }
}

Future<void> _changeLanguagePair({
  required BuildContext context,
  required BuildContext sheetContext,
  required WidgetRef ref,
  required AppCopy copy,
  required LearningLanguageContext currentLanguage,
  required LearningLanguageContext nextLanguage,
  required StateSetter setSheetState,
  required ValueChanged<bool> setSaving,
  required ValueChanged<String?> setError,
}) async {
  if (nextLanguage == currentLanguage) return;
  final String nextLabel = copy.languagePairLabel(
    nativeCode: nextLanguage.nativeLanguage.code,
    targetCode: nextLanguage.targetLanguage.code,
  );
  final bool confirmed = await _showPreferenceChangeDialog(
    context: context,
    copy: copy,
    message: copy.changeLanguagePairMessage(nextLabel),
  );
  if (!confirmed || !sheetContext.mounted) return;

  setSheetState(() {
    setSaving(true);
    setError(null);
  });
  try {
    await ref
        .read(languagePreferencesRepositoryProvider)
        .updateLanguagePreferences(nextLanguage);
    ref.invalidate(languagePreferencesControllerProvider);
    await ref.read(authControllerProvider.notifier).restoreSession();
    if (sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }
  } on Object {
    if (sheetContext.mounted) {
      setSheetState(() => setError(copy.languagePairSaveFailed));
    }
  } finally {
    if (sheetContext.mounted) {
      setSheetState(() => setSaving(false));
    }
  }
}

Future<bool> _showPreferenceChangeDialog({
  required BuildContext context,
  required AppCopy copy,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(copy.preferenceChangeConfirmationTitle),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(copy.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(copy.confirmChangeLabel),
            ),
          ],
        ),
      ) ??
      false;
}

String _initialFor(String name) {
  final String normalized = name.trim();
  if (normalized.isEmpty) {
    return '?';
  }
  return normalized.characters.first.toUpperCase();
}
