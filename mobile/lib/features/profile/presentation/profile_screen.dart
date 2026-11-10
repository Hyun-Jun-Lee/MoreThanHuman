import 'package:curitalk/app/theme/tokens/tokens.dart';
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
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static final List<LearningLanguageContext> _mobileLanguageContexts =
      LearningLanguageContext.supportedContexts
          .where((option) => option.isAvailableInMobileSelector)
          .toList(growable: false);

  bool isLoggingOut = false;
  bool isDeletingAccount = false;
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
    final entitlementState = ref.watch(billingEntitlementProvider);
    final entitlement = entitlementState.isLoading || entitlementState.hasError
        ? null
        : entitlementState.asData?.value;
    final planLabel = entitlement == null
        ? '—'
        : copy.planDisplayName(entitlement.plan);
    final planTitle = entitlement == null
        ? entitlementState.isLoading
              ? copy.profilePlanLoading
              : copy.profilePlanLoadFailed
        : copy.profilePlanTitle(entitlement.plan);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool actionsDisabled =
        isLoggingOut ||
        isDeletingAccount ||
        isSavingLanguage ||
        isSavingAppLocale;
    return AppScaffold(
      backgroundColor: colors.surfaceContainer,
      padding: EdgeInsets.zero,
      safeAreaBottom: false,
      appBar: AppBar(
        title: Text(copy.profileLabel),
        backgroundColor: colors.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              SingleChildScrollView(
                controller: MainTabScope.maybeOf(context)?.controllers[1],
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xxs,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _ProfileSurface(
                        key: const ValueKey('profile-card'),
                        onTap: user == null
                            ? null
                            : () => showNicknameDialog(
                                context,
                                requiredSetup: false,
                                initialNickname: user.nickname ?? user.name,
                              ),
                        semanticLabel: copy.nicknameEditLabel,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: <Widget>[
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppPalette.blockPink,
                                child: Text(
                                  _initialFor(name),
                                  style: AppTypography.button.copyWith(
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  name,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: colors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (Theme.of(context).platform == TargetPlatform.iOS) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _ProfileSectionLabel(copy.subscriptionTitle),
                        const SizedBox(height: AppSpacing.xs),
                        _ProfileSurface(
                          key: const ValueKey('profile-subscription-options'),
                          onTap: () => context.push(AppRoute.paywall),
                          semanticLabel: copy.profileViewPlansLabel,
                          child: ConstrainedBox(
                            key: const ValueKey('profile-plan-action'),
                            constraints: const BoxConstraints(minHeight: 72),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                children: <Widget>[
                                  if (entitlementState.isLoading)
                                    Semantics(
                                      label: copy.profilePlanLoading,
                                      child: Image.asset(
                                        'assets/images/loading/profile_subscription_tomato.gif',
                                        key: const ValueKey(
                                          'profile-subscription-loading',
                                        ),
                                        width: 42,
                                        height: 42,
                                        excludeFromSemantics: true,
                                      ),
                                    )
                                  else
                                    Container(
                                      height: 42,
                                      constraints: const BoxConstraints(
                                        minWidth: 42,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.xs,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.pill,
                                        ),
                                      ),
                                      child: Text(
                                        planLabel,
                                        style: AppTypography.caption.copyWith(
                                          color: colors.onPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          planTitle,
                                          style: AppTypography.button,
                                        ),
                                        const SizedBox(height: AppSpacing.xxs),
                                        Text(
                                          entitlementState.isLoading
                                              ? copy.profilePlanLoadingHint
                                              : entitlementState.hasError
                                              ? copy.profilePlanRefreshHint
                                              : copy.profileCurrentPlanDescription,
                                          style: AppTypography.caption.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    copy.profileViewPlansLabel,
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xxs),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _ProfileSectionLabel(copy.languageSettingsSectionLabel),
                      const SizedBox(height: AppSpacing.xs),
                      _ProfileSurface(
                        key: const ValueKey('profile-language-settings-card'),
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: LayoutBuilder(
                                builder:
                                    (
                                      BuildContext context,
                                      BoxConstraints rowConstraints,
                                    ) {
                                      final selector =
                                          _ProfileSegmentedControl<String>(
                                            values: const <String>['ko', 'en'],
                                            selectedValue: selectedAppLocale,
                                            labelBuilder: (String value) =>
                                                value == 'ko'
                                                ? copy.appLanguageKoreanLabel
                                                : copy.appLanguageEnglishLabel,
                                            keyBuilder: (String value) =>
                                                ValueKey(
                                                  'profile-app-language-$value',
                                                ),
                                            onSelected: actionsDisabled
                                                ? null
                                                : _changeAppLocale,
                                          );
                                      final description = _ProfileSettingCopy(
                                        title: copy.appLanguageSectionLabel,
                                        description:
                                            copy.appLanguageDescription,
                                      );
                                      if (rowConstraints.maxWidth < 320) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            description,
                                            const SizedBox(
                                              height: AppSpacing.sm,
                                            ),
                                            selector,
                                          ],
                                        );
                                      }
                                      return Row(
                                        children: <Widget>[
                                          Expanded(child: description),
                                          const SizedBox(width: AppSpacing.md),
                                          SizedBox(width: 148, child: selector),
                                        ],
                                      );
                                    },
                              ),
                            ),
                            if (appLocaleError != null)
                              _ProfileInlineMessage(
                                message: appLocaleError!,
                                color: colors.error,
                              ),
                            if (isSavingAppLocale)
                              const Padding(
                                padding: EdgeInsets.only(bottom: AppSpacing.md),
                                child: AppLoadingIndicator(width: 120),
                              ),
                            Divider(
                              height: AppSpacing.hair,
                              indent: AppSpacing.md,
                              color: colors.outlineVariant,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _ProfileSettingCopy(
                                    title: copy.languagePairSectionLabel,
                                    description:
                                        copy.learningLanguageDescription,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _ProfileSegmentedControl<
                                    LearningLanguageContext
                                  >(
                                    key: const ValueKey(
                                      'profile-language-pair-options',
                                    ),
                                    values: _mobileLanguageContexts,
                                    selectedValue: selectedLanguage,
                                    labelBuilder: (option) =>
                                        _languagePairChipLabel(copy, option),
                                    onSelected: actionsDisabled
                                        ? null
                                        : _changeLanguagePair,
                                  ),
                                ],
                              ),
                            ),
                            if (languageError != null)
                              _ProfileInlineMessage(
                                message: languageError!,
                                color: colors.error,
                                liveRegion: true,
                              ),
                            if (isSavingLanguage)
                              const Padding(
                                padding: EdgeInsets.only(bottom: AppSpacing.md),
                                child: AppLoadingIndicator(width: 120),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ProfileSectionLabel(copy.accountLabel),
                      const SizedBox(height: AppSpacing.xs),
                      _ProfileSurface(
                        key: const ValueKey('profile-account-card'),
                        child: Column(
                          children: <Widget>[
                            _ProfileAccountAction(
                              key: const ValueKey('profile-logout-action'),
                              label: copy.logOutLabel,
                              onTap: actionsDisabled
                                  ? null
                                  : () async {
                                      setState(() => isLoggingOut = true);
                                      try {
                                        await ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .logout();
                                      } finally {
                                        if (mounted) {
                                          setState(() => isLoggingOut = false);
                                        }
                                      }
                                    },
                            ),
                            Divider(
                              height: AppSpacing.hair,
                              indent: AppSpacing.md,
                              color: colors.outlineVariant,
                            ),
                            _ProfileAccountAction(
                              key: const ValueKey(
                                'profile-delete-account-action',
                              ),
                              label: copy.deleteAccountLabel,
                              color: colors.error,
                              onTap: user == null || actionsDisabled
                                  ? null
                                  : _deleteAccount,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _refreshProfile() async {
    if (isLoggingOut ||
        isDeletingAccount ||
        isSavingLanguage ||
        isSavingAppLocale) {
      return;
    }
    var failed = false;
    try {
      await ref.read(authControllerProvider.notifier).reloadProfile();
    } on Object {
      failed = true;
    }
    if (!mounted) return;
    ref.invalidate(billingEntitlementProvider);
    try {
      await ref.read(billingEntitlementProvider.future);
    } on Object {
      failed = true;
    }
    if (failed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.of(context).failureMessage('profileRefreshFailed'),
          ),
        ),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(authControllerProvider).value?.user;
    if (user == null) return;
    final copy = AppCopy.of(context);
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.deleteAccountLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.deleteAccountWarning),
              if (isIos) ...[
                const SizedBox(height: AppSpacing.md),
                Text(copy.deleteAccountSubscriptionWarning),
                Align(
                  alignment: Alignment.center,
                  child: OutlinedButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://apps.apple.com/account/subscriptions'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(copy.manageSubscription),
                  ),
                ),
              ],
              if (user.oauthProvider == 'apple') ...[
                const SizedBox(height: AppSpacing.md),
                Text(copy.deleteAccountAppleWarning),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              copy.deleteAccountLabel,
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => isDeletingAccount = true);
    try {
      AppleIdentityTokens? appleTokens;
      if (user.oauthProvider == 'apple') {
        try {
          appleTokens = await ref.read(appleIdentityServiceProvider).signIn();
        } on Object {
          // Apple 재인증 실패는 계정 데이터 삭제를 막지 않아요.
        }
      }
      final result = await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(appleTokens: appleTokens);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${result.status == 'completed' ? copy.deletionCompleted : copy.deletionProcessing}'
              '${result.appleDisconnectRequired ? ' ${copy.deletionAppleManual}' : ''}'
              '${result.localCleanupFailed ? ' ${copy.deletionLocalCleanupFailed}' : ''}',
            ),
          ),
        );
      }
    } on Object {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(copy.deletionFailed)));
      }
    } finally {
      if (mounted) setState(() => isDeletingAccount = false);
    }
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

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({
    required this.child,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius borderRadius = BorderRadius.circular(AppRadius.lg);
    final Widget content = onTap == null
        ? child
        : Semantics(
            button: true,
            label: semanticLabel,
            child: Tooltip(
              message: semanticLabel ?? '',
              child: InkWell(
                borderRadius: borderRadius,
                onTap: onTap,
                child: child,
              ),
            ),
          );
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xs),
    child: Text(
      label,
      style: AppTypography.caption.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ProfileSettingCopy extends StatelessWidget {
  const _ProfileSettingCopy({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: AppTypography.button),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          description,
          style: AppTypography.caption.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ProfileSegmentedControl<T> extends StatelessWidget {
  const _ProfileSegmentedControl({
    required this.values,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
    this.keyBuilder,
    super.key,
  });

  final List<T> values;
  final T selectedValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T>? onSelected;
  final Key Function(T value)? keyBuilder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          for (final T value in values)
            Expanded(
              child: Semantics(
                selected: value == selectedValue,
                button: true,
                child: Material(
                  key: keyBuilder?.call(value),
                  color: value == selectedValue
                      ? colors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onSelected == null
                        ? null
                        : () {
                            onSelected!(value);
                          },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          child: Text(
                            labelBuilder(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: value == selectedValue
                                  ? colors.onPrimary
                                  : colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileInlineMessage extends StatelessWidget {
  const _ProfileInlineMessage({
    required this.message,
    required this.color,
    this.liveRegion = false,
  });

  final String message;
  final Color color;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: liveRegion,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Text(message, style: AppTypography.bodySm.copyWith(color: color)),
    ),
  );
}

class _ProfileAccountAction extends StatelessWidget {
  const _ProfileAccountAction({
    required this.label,
    required this.onTap,
    this.color,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color foreground = color ?? colors.onSurface;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodySm.copyWith(
                      color: onTap == null
                          ? foreground.withValues(alpha: 0.38)
                          : foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: onTap == null
                      ? colors.onSurfaceVariant.withValues(alpha: 0.38)
                      : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
