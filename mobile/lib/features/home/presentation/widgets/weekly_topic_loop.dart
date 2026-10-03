import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:flutter/material.dart';

const _topicColors = <Color>[
  AppPalette.blockBlue,
  AppPalette.blockPink,
  AppPalette.blockLime,
  AppPalette.blockLilac,
  AppPalette.blockCoral,
  AppPalette.blockCream,
  AppPalette.blockLimeSoft,
  AppPalette.blockLilacSoft,
];

class WeeklyTopicLoop extends StatefulWidget {
  const WeeklyTopicLoop({
    required this.topics,
    required this.onSelected,
    super.key,
  });

  final List<WeeklyTopic> topics;
  final ValueChanged<WeeklyTopic>? onSelected;

  @override
  State<WeeklyTopicLoop> createState() => _WeeklyTopicLoopState();
}

class _WeeklyTopicLoopState extends State<WeeklyTopicLoop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  bool _touching = false;
  bool _appActive = true;

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
              color: _topicColors[index % _topicColors.length],
              onTap: widget.onSelected,
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
      child: SizedBox(
        height: 112,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const step = 172.0;
            const itemWidth = 156.0;
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
                                ((index * step + _motion.value * total) %
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
                                color:
                                    _topicColors[index % _topicColors.length],
                                onTap: widget.onSelected,
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
    );
  }
}

class _TopicButton extends StatelessWidget {
  const _TopicButton({
    required this.topic,
    required this.color,
    required this.onTap,
    this.keySuffix,
  });

  final WeeklyTopic topic;
  final Color color;
  final ValueChanged<WeeklyTopic>? onTap;
  final String? keySuffix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: topic.text,
      child: Material(
        key: ValueKey(
          'weekly-topic-card-${topic.id}${keySuffix == null ? '' : '-$keySuffix'}',
        ),
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(
            'weekly-topic-${topic.id}${keySuffix == null ? '' : '-$keySuffix'}',
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap == null ? null : () => onTap!(topic),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              topic.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
