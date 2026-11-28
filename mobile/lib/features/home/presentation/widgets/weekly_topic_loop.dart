import 'dart:math' as math;

import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:text_ko/text_ko.dart';

const _topicCardWidth = 156.0;
const _topicCardPadding = EdgeInsets.fromLTRB(10, 18, 10, 12);

class WeeklyTopicLoop extends StatefulWidget {
  const WeeklyTopicLoop({
    required this.topics,
    required this.onSelected,
    this.selectedTopicId,
    super.key,
  });

  final List<WeeklyTopic> topics;
  final ValueChanged<WeeklyTopic>? onSelected;
  final String? selectedTopicId;

  @override
  State<WeeklyTopicLoop> createState() => _WeeklyTopicLoopState();
}

class _WeeklyTopicLoopState extends State<WeeklyTopicLoop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _touching = false;
  bool _appActive = true;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMotion();
    });
  }

  void _syncMotion() {
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final reduceMotion =
        media.disableAnimations ||
        media.accessibleNavigation ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion;
    final shouldRun =
        _appActive &&
        !_touching &&
        widget.selectedTopicId == null &&
        !reduceMotion &&
        TickerMode.valuesOf(context).enabled &&
        widget.onSelected != null &&
        widget.topics.isNotEmpty;
    if (shouldRun && !_motion.isAnimating) _motion.repeat();
    if (!shouldRun && _motion.isAnimating) _motion.stop();
  }

  @override
  void didUpdateWidget(covariant WeeklyTopicLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMotion();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.topics.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: _buildTopics);
  }

  Widget _buildTopics(BuildContext context, BoxConstraints constraints) {
    final media = MediaQuery.of(context);
    final staticMode =
        media.disableAnimations ||
        media.accessibleNavigation ||
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .reduceMotion ||
        media.textScaler.scale(1) > 1.3;
    final cardWidth = math.min(
      media.textScaler.scale(1) > 1.3 ? constraints.maxWidth : _topicCardWidth,
      constraints.maxWidth,
    );
    final textStyle =
        (Theme.of(context).textTheme.bodyMedium ??
                DefaultTextStyle.of(context).style)
            .copyWith(color: AppPalette.ink);
    final cardHeight = _measureCardHeight(context, cardWidth, textStyle);
    if (staticMode) {
      return Wrap(
        key: const ValueKey('weekly-topics-static'),
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var index = 0; index < widget.topics.length; index++)
            _TopicButton(
              topic: widget.topics[index],
              selected: widget.selectedTopicId == widget.topics[index].id,
              onTap: widget.onSelected,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              textStyle: textStyle,
            ),
        ],
      );
    }
    return Listener(
      onPointerDown: (_) {
        _touching = true;
        _syncMotion();
      },
      onPointerUp: (_) {
        _touching = false;
        _syncMotion();
      },
      onPointerCancel: (_) {
        _touching = false;
        _syncMotion();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragUpdate: (details) {
          final total = widget.topics.length * (cardWidth + 16);
          if (total == 0) return;
          setState(() {
            _dragOffset =
                ((_dragOffset + details.delta.dx) % total + total) % total;
          });
        },
        child: SizedBox(
          // 곡선의 최대 이동 28px + 꼭지 여백 13px + 하단 여유 3px예요.
          height: cardHeight + 44,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final step = cardWidth + 16;
              final itemWidth = cardWidth;
              final total = widget.topics.length * step;
              final copies = (constraints.maxWidth / total).ceil() + 1;
              return ClipRect(
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => Stack(
                    children: [
                      for (var index = 0; index < widget.topics.length; index++)
                        for (var copy = 0; copy <= copies; copy++)
                          Builder(
                            builder: (context) {
                              final x =
                                  ((index * step +
                                          _motion.value * total +
                                          _dragOffset) %
                                      total) -
                                  step +
                                  copy * total;
                              final fraction =
                                  (x + itemWidth / 2) / constraints.maxWidth;
                              final centered = (fraction * 2 - 1).clamp(
                                -1.0,
                                1.0,
                              );
                              final y = 18 + 10 * (1 - centered * centered);
                              return Positioned(
                                left: x,
                                top: y,
                                width: itemWidth,
                                child: _TopicButton(
                                  topic: widget.topics[index],
                                  selected:
                                      widget.selectedTopicId ==
                                      widget.topics[index].id,
                                  onTap: widget.onSelected,
                                  cardWidth: itemWidth,
                                  cardHeight: cardHeight,
                                  textStyle: textStyle,
                                  keySuffix: '$copy',
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _measureCardHeight(
    BuildContext context,
    double width,
    TextStyle style,
  ) {
    final media = MediaQuery.of(context);
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textAlign: TextAlign.center,
      textScaler: media.textScaler,
      locale: Localizations.maybeLocaleOf(context),
    );
    var height = 104.0;
    // 실제 표시와 같은 한국어 어절 처리·서체·접근성 배율로 측정해요.
    for (final topic in widget.topics) {
      painter.text = TextSpan(
        text: applyTextKoWordBreak(
          topic.text,
          wordBreak: TextKoWordBreak.keepAll,
        ),
        style: media.boldText
            ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
            : style,
      );
      painter.layout(
        maxWidth: math.max(1, width - _topicCardPadding.horizontal),
      );
      height = math.max(
        height,
        painter.height.ceilToDouble() + _topicCardPadding.vertical,
      );
    }
    painter.dispose();
    return height;
  }
}

class _TopicButton extends StatelessWidget {
  const _TopicButton({
    required this.topic,
    required this.selected,
    required this.onTap,
    required this.cardWidth,
    required this.cardHeight,
    required this.textStyle,
    this.keySuffix,
  });

  final WeeklyTopic topic;
  final bool selected;
  final ValueChanged<WeeklyTopic>? onTap;
  final double cardWidth;
  final double cardHeight;
  final TextStyle textStyle;
  final String? keySuffix;

  @override
  Widget build(BuildContext context) {
    final text = TextKo(
      topic.text,
      wordBreak: TextKoWordBreak.keepAll,
      semanticsLabel: topic.text,
      style: textStyle,
      textAlign: TextAlign.center,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: topic.text,
      child: Padding(
        padding: const EdgeInsets.only(top: 13),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: Material(
                key: ValueKey(
                  'weekly-topic-card-${topic.id}${keySuffix == null ? '' : '-$keySuffix'}',
                ),
                color: selected
                    ? AppPalette.topicSelectedSurface
                    : AppPalette.topicSurface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey(
                    'weekly-topic-${topic.id}${keySuffix == null ? '' : '-$keySuffix'}',
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  onTap: onTap == null ? null : () => onTap!(topic),
                  child: Padding(
                    padding: _topicCardPadding,
                    child: Center(child: text),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: -13,
              child: IgnorePointer(child: _TomatoCalyx()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TomatoCalyx extends StatelessWidget {
  const _TomatoCalyx();

  @override
  Widget build(BuildContext context) {
    // 원본 PNG의 투명 여백을 위젯에서 잘라 꼭지 부분만 보여줘요.
    return SizedBox(
      width: 40,
      height: 25.3,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: -15.5,
              top: -6.3,
              child: Image.asset(
                'assets/images/weekly_topic/tomato_calyx.png',
                width: 73.3,
                height: 73.3,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
