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
    final String localeCode = _onboardingLocaleCode(context);
    final _OnboardingCopy copy = _OnboardingCopy.forLocale(localeCode);

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
                      localeCode: localeCode,
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
    required this.localeCode,
    required this.selected,
    required this.onChanged,
  });

  final _OnboardingPageCopy copy;
  final String localeCode;
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
        localeCode: localeCode,
      ),
    );
  }
}

class _InterestPage extends StatelessWidget {
  const _InterestPage({required this.copy});

  final _InterestPageCopy copy;

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

class _OnboardingCopy {
  const _OnboardingCopy({
    required this.backLabel,
    required this.skipLabel,
    required this.continueLabel,
    required this.getStartedLabel,
    required this.languagePair,
    required this.interest,
    required this.topicPrep,
    required this.feedback,
  });

  final String backLabel;
  final String skipLabel;
  final String continueLabel;
  final String getStartedLabel;
  final _OnboardingPageCopy languagePair;
  final _InterestPageCopy interest;
  final _TopicPrepPageCopy topicPrep;
  final _FeedbackPageCopy feedback;

  static _OnboardingCopy forLocale(String localeCode) {
    return switch (localeCode) {
      'ko' => const _OnboardingCopy(
        backLabel: '뒤로',
        skipLabel: '건너뛰기',
        continueLabel: '계속',
        getStartedLabel: '시작하기',
        languagePair: _OnboardingPageCopy(
          title: '무엇을 연습할까요?',
          description: '대화 언어와 피드백 언어를 먼저 선택하세요.',
        ),
        interest: _InterestPageCopy(
          title: '진짜 관심사를\n이야기해요.',
          description: '뉴스, 취미, 스포츠, 여행처럼 마음에 있는 주제로 회화를 연습해요.',
          leftMessage: '어디로 가세요?',
          rightMessage: '다음 주에 오사카에 가요!',
          chips: <String>['오사카 맛집', '야구', 'AI 뉴스'],
        ),
        topicPrep: _TopicPrepPageCopy(
          title: '말하기 전에\n가볍게 준비해요.',
          description: 'Curitalk이 배경 정보를 모으고 시작 질문을 준비해 처음 말하기가 쉬워져요.',
          sectionLabel: '주제 요약',
          topicTitle: '커리어 전환\n준비하기',
          helperText: '대화를 위한 질문 3개가 준비됐어요.',
        ),
        feedback: _FeedbackPageCopy(
          title: '부담 없이\n나아져요.',
          description: '대화 흐름은 유지하면서 메시지 아래에서 부드러운 제안을 확인해요.',
          originalMessage: 'I go to Dotonbori yesterday.',
          correctionText: '제안: I went to Dotonbori yesterday.',
          reasonText: '이유: 과거 시제 + 장소',
        ),
      ),
      _ => const _OnboardingCopy(
        backLabel: 'BACK',
        skipLabel: 'SKIP',
        continueLabel: 'CONTINUE',
        getStartedLabel: 'GET STARTED',
        languagePair: _OnboardingPageCopy(
          title: 'What do you want\nto practice?',
          description:
              'Choose your conversation language and feedback language.',
        ),
        interest: _InterestPageCopy(
          title: 'Talk about what\nyou actually care about.',
          description:
              'Practice conversation with news, hobbies, sports, travel, or anything on your mind.',
          leftMessage: 'Where are you heading?',
          rightMessage: "I'm going to Osaka next week!",
          chips: <String>['OSAKA FOOD', 'BASEBALL', 'AI NEWS'],
        ),
        topicPrep: _TopicPrepPageCopy(
          title: 'Get ready before\nyou speak.',
          description:
              'Curitalk gathers helpful context and gives you starter questions, so beginning feels easy.',
          sectionLabel: 'Topic summary',
          topicTitle: 'Navigating\nCareer Transitions',
          helperText: 'Three useful questions are ready for your conversation.',
        ),
        feedback: _FeedbackPageCopy(
          title: 'Improve without\npressure.',
          description:
              'See gentle suggestions under your messages while the conversation keeps flowing.',
          originalMessage: 'I go to Dotonbori yesterday.',
          correctionText: 'Try: I went to Dotonbori yesterday.',
          reasonText: 'Why: past tense + place',
        ),
      ),
    };
  }
}

class _OnboardingPageCopy {
  const _OnboardingPageCopy({required this.title, required this.description});

  final String title;
  final String description;
}

class _InterestPageCopy extends _OnboardingPageCopy {
  const _InterestPageCopy({
    required super.title,
    required super.description,
    required this.leftMessage,
    required this.rightMessage,
    required this.chips,
  });

  final String leftMessage;
  final String rightMessage;
  final List<String> chips;
}

class _TopicPrepPageCopy extends _OnboardingPageCopy {
  const _TopicPrepPageCopy({
    required super.title,
    required super.description,
    required this.sectionLabel,
    required this.topicTitle,
    required this.helperText,
  });

  final String sectionLabel;
  final String topicTitle;
  final String helperText;
}

class _FeedbackPageCopy extends _OnboardingPageCopy {
  const _FeedbackPageCopy({
    required super.title,
    required super.description,
    required this.originalMessage,
    required this.correctionText,
    required this.reasonText,
  });

  final String originalMessage;
  final String correctionText;
  final String reasonText;
}

class _TopicPrepPage extends StatelessWidget {
  const _TopicPrepPage({required this.copy});

  final _TopicPrepPageCopy copy;

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

  final _FeedbackPageCopy copy;

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

String _onboardingLocaleCode(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ko' ? 'ko' : 'en';
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
