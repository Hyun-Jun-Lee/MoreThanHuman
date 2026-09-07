import 'dart:async';

import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter/material.dart';

class LanguageSnackCarousel extends StatefulWidget {
  const LanguageSnackCarousel({required this.snacks, super.key});

  static const Duration autoAdvanceInterval = Duration(seconds: 5);

  final List<LanguageSnack> snacks;

  @override
  State<LanguageSnackCarousel> createState() => _LanguageSnackCarouselState();
}

class _LanguageSnackCarouselState extends State<LanguageSnackCarousel>
    with WidgetsBindingObserver {
  static const List<Color> _colors = <Color>[
    AppPalette.blockLilac,
    AppPalette.blockBlue,
    AppPalette.blockLimeSoft,
    AppPalette.blockPink,
    AppPalette.blockCream,
  ];

  Timer? _autoAdvanceTimer;
  Timer? _resumeTimer;
  int _currentIndex = 0;
  bool _isAppActive = true;
  bool _hasControlFocus = false;
  bool _isManualInteractionPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAutoAdvanceTimer();
  }

  @override
  void didUpdateWidget(covariant LanguageSnackCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex >= widget.snacks.length) {
      _currentIndex = 0;
    }
    _syncAutoAdvanceTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    _syncAutoAdvanceTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoAdvanceTimer?.cancel();
    _resumeTimer?.cancel();
    super.dispose();
  }

  bool get _shouldAutoAdvance {
    return widget.snacks.length > 1 &&
        _isAppActive &&
        !_hasControlFocus &&
        !_isManualInteractionPaused &&
        !MediaQuery.disableAnimationsOf(context);
  }

  void _syncAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (!_shouldAutoAdvance) {
      return;
    }
    _autoAdvanceTimer = Timer.periodic(
      LanguageSnackCarousel.autoAdvanceInterval,
      (_) {
        if (!mounted || !_shouldAutoAdvance) {
          return;
        }
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.snacks.length;
        });
      },
    );
  }

  void _selectSnack(int index) {
    final int normalizedIndex = index % widget.snacks.length;
    setState(() {
      _currentIndex = normalizedIndex < 0
          ? normalizedIndex + widget.snacks.length
          : normalizedIndex;
      _isManualInteractionPaused = true;
    });
    _autoAdvanceTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(LanguageSnackCarousel.autoAdvanceInterval, () {
      if (!mounted) {
        return;
      }
      setState(() => _isManualInteractionPaused = false);
      _syncAutoAdvanceTimer();
    });
  }

  void _handleControlFocus(bool hasFocus) {
    _hasControlFocus = hasFocus;
    if (hasFocus) {
      _autoAdvanceTimer?.cancel();
      _resumeTimer?.cancel();
      return;
    }
    _isManualInteractionPaused = false;
    _syncAutoAdvanceTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.snacks.isEmpty) {
      return const SizedBox.shrink();
    }

    final AppCopy copy = AppCopy.of(context);
    final LanguageSnack snack = widget.snacks[_currentIndex];
    final bool hasMultipleSnacks = widget.snacks.length > 1;
    final Duration transitionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.standard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSectionLabel(copy.languageSnackLabel),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          container: true,
          label: copy.languageSnackSemanticLabel(
            leftLabel: snack.leftLabel,
            leftWord: snack.leftWord,
            rightLabel: snack.rightLabel,
            rightWord: snack.rightWord,
            meaning: snack.meaning,
          ),
          child: AnimatedSwitcher(
            duration: transitionDuration,
            child: _LanguageSnackCard(
              key: ValueKey<String>(snack.id),
              snack: snack,
              color: _colors[_currentIndex % _colors.length],
            ),
          ),
        ),
        if (hasMultipleSnacks) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          FocusScope(
            onFocusChange: _handleControlFocus,
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: copy.previousLanguageSnackTooltip,
                  onPressed: () => _selectSnack(_currentIndex - 1),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(widget.snacks.length, (
                      int index,
                    ) {
                      final bool isSelected = index == _currentIndex;
                      return IconButton(
                        tooltip: copy.languageSnackPageTooltip(index + 1),
                        onPressed: () => _selectSnack(index),
                        constraints: const BoxConstraints.tightFor(
                          width: AppSize.touchTarget,
                          height: AppSize.touchTarget,
                        ),
                        icon: Icon(
                          Icons.circle,
                          size: isSelected ? 10 : 7,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.outline,
                        ),
                      );
                    }),
                  ),
                ),
                IconButton(
                  tooltip: copy.nextLanguageSnackTooltip,
                  onPressed: () => _selectSnack(_currentIndex + 1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LanguageSnackCard extends StatelessWidget {
  const _LanguageSnackCard({
    required this.snack,
    required this.color,
    super.key,
  });

  final LanguageSnack snack;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color foreground = Theme.of(context).colorScheme.onSurface;
    return AppColorBlockCard(
      color: color,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              snack.category.toUpperCase(),
              style: AppTypography.captionMono.copyWith(color: foreground),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _Expression(
                    label: snack.leftLabel,
                    word: snack.leftWord,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Expression(
                    label: snack.rightLabel,
                    word: snack.rightWord,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: foreground.withValues(alpha: 0.16), height: 1),
            const SizedBox(height: AppSpacing.md),
            Text(
              snack.meaning,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(color: foreground),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              snack.example,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Expression extends StatelessWidget {
  const _Expression({required this.label, required this.word});

  final String label;
  final String word;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.captionMono.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          word,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headlineMd.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
