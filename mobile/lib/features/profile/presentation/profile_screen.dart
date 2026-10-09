import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'dart:io';
import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool isLoggingOut = false;
  bool isSavingLanguage = false;
  bool isSavingAppLocale = false;
  String? languageError;
  String? appLocaleError;
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value?.user;
    final selectedLanguage =
        user?.language ?? LearningLanguageContext.defaultContext;
    final selectedAppLocale =
        user?.appLocale ??
        (Localizations.localeOf(context).languageCode == 'ko' ? 'ko' : 'en');
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'tomatalk user';
    final email = user?.email.trim() ?? '';
    final copy = AppCopy.of(context);
    final entitlement = ref.watch(billingEntitlementProvider).value;
    return AppScaffold(
      safeAreaBottom: false,
      appBar: AppBar(title: Text(copy.profileLabel)),
      body: SingleChildScrollView(
        controller: MainTabScope.maybeOf(context)?.controllers[1],
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
            if (Platform.isIOS) ...[
              AppSectionLabel(copy.subscriptionTitle),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                title: Text(copy.currentPlan(entitlement?.plan ?? 'free')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(AppRoute.paywall),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            AppPrimaryButton(
              label: copy.logOutLabel,
              isLoading: isLoggingOut,
              onPressed: isLoggingOut || isSavingLanguage || isSavingAppLocale
                  ? null
                  : () async {
                      setState(() => isLoggingOut = true);
                      try {
                        await ref
                            .read(authControllerProvider.notifier)
                            .logout();
                      } finally {
                        if (mounted) setState(() => isLoggingOut = false);
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
                  onSelected:
                      isSavingAppLocale || isSavingLanguage || isLoggingOut
                      ? null
                      : (_) async {
                          await _changeAppLocale('ko');
                        },
                ),
                AppSelectionChip(
                  label: copy.appLanguageEnglishLabel,
                  selected: selectedAppLocale == 'en',
                  onSelected:
                      isSavingAppLocale || isSavingLanguage || isLoggingOut
                      ? null
                      : (_) async {
                          await _changeAppLocale('en');
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
                await _changeLanguagePair(next);
              },
              enabled: !isSavingLanguage && !isSavingAppLocale && !isLoggingOut,
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
      ),
    );
  }

  Future<void> _changeAppLocale(String nextLocale) async {
    final copy = AppCopy.of(context);
    final user = ref.read(authControllerProvider).value?.user;
    if (nextLocale == user?.appLocale) return;
    final bool confirmed = await _showPreferenceChangeDialog(
      context: context,
      copy: copy,
      message: copy.changeAppLanguageMessage(copy.languageName(nextLocale)),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      isSavingAppLocale = true;
      appLocaleError = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateAppLocale(nextLocale);
    } on Object {
      if (mounted) {
        setState(() => appLocaleError = copy.appLanguageSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => isSavingAppLocale = false);
      }
    }
  }

  Future<void> _changeLanguagePair(LearningLanguageContext nextLanguage) async {
    final copy = AppCopy.of(context);
    final currentLanguage = ref
        .read(authControllerProvider)
        .value
        ?.user
        ?.language;
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
    if (!confirmed || !mounted) return;

    setState(() {
      isSavingLanguage = true;
      languageError = null;
    });
    try {
      await ref
          .read(languagePreferencesRepositoryProvider)
          .updateLanguagePreferences(nextLanguage);
      ref.invalidate(languagePreferencesControllerProvider);
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } on Object {
      if (mounted) {
        setState(() => languageError = copy.languagePairSaveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => isSavingLanguage = false);
      }
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
