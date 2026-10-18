import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/app_component_themes.dart';
import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/profile/presentation/nickname_dialog.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const double _sectionContentGap = AppSpacing.md;

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
    final name = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : 'tomatalk user';
    final copy = AppCopy.of(context);
    final entitlement = ref.watch(billingEntitlementProvider).value;
    return AppScaffold(
      safeAreaBottom: false,
      appBar: AppBar(title: Text(copy.profileLabel)),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            SingleChildScrollView(
              controller: MainTabScope.maybeOf(context)?.controllers[1],
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
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
                            child: Text(
                              name,
                              style: AppTypography.bodyLg.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: copy.nicknameEditLabel,
                            onPressed: user == null
                                ? null
                                : () => showNicknameDialog(
                                    context,
                                    requiredSetup: false,
                                    initialNickname: user.nickname ?? user.name,
                                  ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                        AppSectionLabel(copy.subscriptionTitle),
                        const SizedBox(height: _sectionContentGap),
                        Wrap(
                          key: const ValueKey('profile-subscription-options'),
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            Semantics(
                              selected: true,
                              child: Chip(
                                label: Text(
                                  _planLabel(entitlement?.plan ?? 'free'),
                                ),
                                backgroundColor:
                                    AppSemanticColors.light.selectedSurface,
                                labelStyle: AppTypography.caption.copyWith(
                                  color: AppSemanticColors.light.onSelected,
                                ),
                              ),
                            ),
                            ActionChip(
                              label: Text(copy.showMoreLabel),
                              backgroundColor: AppPalette.canvas,
                              labelStyle: AppTypography.caption.copyWith(
                                color: AppPalette.ink,
                              ),
                              onPressed: () => context.push(AppRoute.paywall),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      AppSectionLabel(copy.appLanguageSectionLabel),
                      const SizedBox(height: _sectionContentGap),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: <Widget>[
                          AppSelectionChip(
                            label: copy.appLanguageKoreanLabel,
                            uppercaseLabel: false,
                            selected: selectedAppLocale == 'ko',
                            onSelected:
                                isSavingAppLocale ||
                                    isSavingLanguage ||
                                    isLoggingOut
                                ? null
                                : (_) async {
                                    await _changeAppLocale('ko');
                                  },
                          ),
                          AppSelectionChip(
                            label: copy.appLanguageEnglishLabel,
                            uppercaseLabel: false,
                            selected: selectedAppLocale == 'en',
                            onSelected:
                                isSavingAppLocale ||
                                    isSavingLanguage ||
                                    isLoggingOut
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
                      const SizedBox(height: _sectionContentGap),
                      Wrap(
                        key: const ValueKey('profile-language-pair-options'),
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          for (final option
                              in LearningLanguageContext.supportedContexts)
                            if (option.isAvailableInMobileSelector)
                              AppSelectionChip(
                                label: _languagePairChipLabel(copy, option),
                                selected: option == selectedLanguage,
                                onSelected:
                                    isSavingLanguage ||
                                        isSavingAppLocale ||
                                        isLoggingOut
                                    ? null
                                    : (_) async => _changeLanguagePair(option),
                              ),
                        ],
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
                      const SizedBox(height: AppSpacing.xl),
                      const Spacer(),
                      Center(
                        child: TextButton(
                          style: AppComponentThemes.mutedTextButton,
                          onPressed:
                              isLoggingOut ||
                                  isSavingLanguage ||
                                  isSavingAppLocale
                              ? null
                              : () async {
                                  setState(() => isLoggingOut = true);
                                  try {
                                    await ref
                                        .read(authControllerProvider.notifier)
                                        .logout();
                                  } finally {
                                    if (mounted) {
                                      setState(() => isLoggingOut = false);
                                    }
                                  }
                                },
                          child: Text(copy.logOutLabel),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
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
    final String nextLabel = _languagePairLabel(copy, nextLanguage);
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

  String _planLabel(String plan) {
    final normalized = plan.trim().toLowerCase();
    if (normalized.isEmpty) return 'Free';
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String _languagePairChipLabel(
    AppCopy copy,
    LearningLanguageContext language,
  ) {
    if (!copy.isKorean) {
      return '${language.nativeLanguage.shortCode} → '
          '${language.targetLanguage.shortCode}';
    }
    return _languagePairLabel(copy, language);
  }

  String _languagePairLabel(AppCopy copy, LearningLanguageContext language) {
    return '${copy.languageName(language.nativeLanguage.code)} → '
        '${copy.languageName(language.targetLanguage.code)}';
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
