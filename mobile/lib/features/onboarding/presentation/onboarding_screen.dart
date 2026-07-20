import 'package:curitalk/app/theme/tokens/tokens.dart';
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
                        label: const Text('BACK'),
                      )
                    else
                      const SizedBox.shrink(),
                    TextButton(
                      onPressed: _isCompleting ? null : _complete,
                      child: const Text('SKIP'),
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
                      selected: _selectedLanguage,
                      onChanged: (LearningLanguageContext next) {
                        setState(() => _selectedLanguage = next);
                      },
                    ),
                    const _InterestPage(),
                    const _TopicPrepPage(),
                    const _FeedbackPage(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppPageIndicator(count: _pageCount, currentIndex: _currentIndex),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: _currentIndex == _pageCount - 1
                    ? 'GET STARTED'
                    : 'CONTINUE',
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
  const _LanguagePairPage({required this.selected, required this.onChanged});

  final LearningLanguageContext selected;
  final ValueChanged<LearningLanguageContext> onChanged;

  @override
  Widget build(BuildContext context) {
    final String localeCode = Localizations.localeOf(context).languageCode;
    final _LanguagePairCopy copy = _LanguagePairCopy.forLocale(localeCode);
    return _OnboardingPageLayout(
      title: copy.title,
      description: copy.description,
      illustration: LanguagePairSelector(
        selected: selected,
        onChanged: onChanged,
        localeCode: localeCode,
      ),
    );
  }
}

class _InterestPage extends StatelessWidget {
  const _InterestPage();

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      title: 'Talk about what\nyou actually care about.',
      description:
          'Practice English with news, hobbies, sports, travel, or anything on your mind.',
      illustration: AppColorBlockCard(
        color: AppPalette.blockLilacSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ChatLine(
              text: "Where are you heading?",
              alignment: Alignment.centerLeft,
              color: Theme.of(context).colorScheme.surface,
            ),
            const SizedBox(height: AppSpacing.md),
            const _ChatLine(
              text: "I'm going to Osaka next week!",
              alignment: Alignment.centerRight,
              color: AppPalette.primary,
              textColor: AppPalette.onPrimary,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                Chip(label: Text('OSAKA FOOD')),
                Chip(label: Text('BASEBALL')),
                Chip(label: Text('AI NEWS')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePairCopy {
  const _LanguagePairCopy({required this.title, required this.description});

  final String title;
  final String description;

  static _LanguagePairCopy forLocale(String localeCode) {
    return switch (localeCode) {
      'ko' => const _LanguagePairCopy(
        title: '무엇을 연습할까요?',
        description: '대화 언어와 피드백 언어를 먼저 선택하세요.',
      ),
      'zh' => const _LanguagePairCopy(
        title: '你想练习什么？',
        description: '先选择对话语言和反馈语言。',
      ),
      _ => const _LanguagePairCopy(
        title: 'What do you want\nto practice?',
        description: 'Choose your conversation language and feedback language.',
      ),
    };
  }
}

class _TopicPrepPage extends StatelessWidget {
  const _TopicPrepPage();

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      title: 'Get ready before\nyou speak.',
      description:
          'Curitalk gathers helpful context and gives you starter questions, so beginning feels easy.',
      illustration: const AppColorBlockCard(
        color: AppPalette.blockLime,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSectionLabel('Topic summary'),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Navigating\nCareer Transitions',
              style: AppTypography.headlineLg,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Three useful questions are ready for your conversation.',
              style: AppTypography.bodySm,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackPage extends StatelessWidget {
  const _FeedbackPage();

  @override
  Widget build(BuildContext context) {
    return _OnboardingPageLayout(
      title: 'Improve without\npressure.',
      description:
          'See gentle suggestions under your messages while the conversation keeps flowing.',
      illustration: Column(
        children: const <Widget>[
          AppColorBlockCard(
            color: AppPalette.blockLilac,
            child: Text(
              'I go to Dotonbori yesterday.',
              style: AppTypography.body,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          AppColorBlockCard(
            color: AppPalette.blockCream,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Try: I went to Dotonbori yesterday.',
                  style: AppTypography.body,
                ),
                SizedBox(height: AppSpacing.xs),
                Text('Why: past tense + place', style: AppTypography.bodySm),
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
