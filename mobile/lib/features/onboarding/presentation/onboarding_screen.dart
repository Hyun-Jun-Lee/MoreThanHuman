import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const int _pageCount = 4;

  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isCompleting = false;
  bool _initializedLanguage = false;
  LearningLanguageContext _selectedLanguage =
      LearningLanguageContext.defaultContext;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedLanguage) {
      return;
    }
    _selectedLanguage = defaultLanguageContextForLocale(
      Localizations.localeOf(context).languageCode,
    );
    _initializedLanguage = true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_isCompleting) {
      return;
    }
    setState(() => _isCompleting = true);
    try {
      await ref
          .read(onboardingControllerProvider.notifier)
          .complete(_selectedLanguage);
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  Future<void> _advance() async {
    if (_currentIndex == _pageCount - 1) {
      await _complete();
      return;
    }
    await _pageController.nextPage(
      duration: AppMotion.standard,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppCopy appCopy = AppCopy.of(context);
    final AppOnboardingCopy copy = appCopy.onboarding;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.lg,
          ),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: AppSize.touchTarget,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (_currentIndex > 0)
                      OutlinedButton.icon(
                        onPressed: () => _pageController.previousPage(
                          duration: AppMotion.standard,
                          curve: Curves.easeOut,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(copy.backLabel),
                      )
                    else
                      const SizedBox.shrink(),
                    TextButton(
                      onPressed: _isCompleting ? null : _complete,
                      child: Text(copy.skipLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (int index) {
                    setState(() => _currentIndex = index);
                  },
                  children: <Widget>[
                    _LanguagePairPage(
                      copy: copy.languagePair,
                      selected: _selectedLanguage,
                      onChanged: (LearningLanguageContext next) {
                        setState(() => _selectedLanguage = next);
                      },
                    ),
                    _InterestPage(copy: copy.interest),
                    _TopicPrepPage(copy: copy.topicPrep),
                    _FeedbackPage(copy: copy.feedback),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppPageIndicator(count: _pageCount, currentIndex: _currentIndex),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: _currentIndex == _pageCount - 1
                    ? copy.getStartedLabel
                    : copy.continueLabel,
                isLoading: _isCompleting,
                trailing: _currentIndex == _pageCount - 1
                    ? null
                    : const Icon(Icons.arrow_forward_rounded),
                onPressed: _advance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguagePairPage extends StatelessWidget {
  const _LanguagePairPage({
    required this.copy,
    required this.selected,
    required this.onChanged,
  });

  final AppOnboardingPageCopy copy;
  final LearningLanguageContext selected;
  final ValueChanged<LearningLanguageContext> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      title: copy.title,
      description: copy.description,
      illustration: LanguagePairSelector(
        selected: selected,
        onChanged: onChanged,
      ),
    );
  }
}

class _InterestPage extends StatelessWidget {
  const _InterestPage({required this.copy});

  final AppOnboardingInterestCopy copy;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      title: copy.title,
      description: copy.description,
      illustration: AppColorBlockCard(
        color: AppPalette.blockLilacSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ChatLine(
              text: copy.leftMessage,
              alignment: Alignment.centerLeft,
              color: Theme.of(context).colorScheme.surface,
            ),
            const SizedBox(height: AppSpacing.md),
            _ChatLine(
              text: copy.rightMessage,
              alignment: Alignment.centerRight,
              color: AppPalette.primary,
              textColor: AppPalette.onPrimary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final String chip in copy.chips) Chip(label: Text(chip)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicPrepPage extends StatelessWidget {
  const _TopicPrepPage({required this.copy});

  final AppOnboardingTopicPrepCopy copy;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      title: copy.title,
      description: copy.description,
      illustration: AppColorBlockCard(
        color: AppPalette.blockLime,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionLabel(copy.sectionLabel),
            const SizedBox(height: AppSpacing.lg),
            Text(copy.topicTitle, style: AppTypography.headlineLg),
            const SizedBox(height: AppSpacing.lg),
            Text(copy.helperText, style: AppTypography.bodySm),
          ],
        ),
      ),
    );
  }
}

class _FeedbackPage extends StatelessWidget {
  const _FeedbackPage({required this.copy});

  final AppOnboardingFeedbackCopy copy;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      title: copy.title,
      description: copy.description,
      illustration: Column(
        children: <Widget>[
          AppColorBlockCard(
            color: AppPalette.blockLilac,
            child: Text(copy.originalMessage, style: AppTypography.body),
          ),
          const SizedBox(height: AppSpacing.md),
          AppColorBlockCard(
            color: AppPalette.blockCream,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(copy.correctionText, style: AppTypography.body),
                const SizedBox(height: AppSpacing.xs),
                Text(copy.reasonText, style: AppTypography.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageLayout extends StatelessWidget {
  const _OnboardingPageLayout({
    required this.title,
    required this.description,
    required this.illustration,
  });

  final String title;
  final String description;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTypography.headlineLg),
          const SizedBox(height: AppSpacing.md),
          Text(
            description,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          illustration,
        ],
      ),
    );
  }
}

class _ChatLine extends StatelessWidget {
  const _ChatLine({
    required this.text,
    required this.alignment,
    required this.color,
    this.textColor,
  });

  final String text;
  final Alignment alignment;
  final Color color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
        child: Text(
          text,
          style: AppTypography.bodySm.copyWith(color: textColor),
        ),
      ),
    );
  }
}
