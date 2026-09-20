import 'dart:math' as math;

import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/home/domain/daily_snack_basket.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/presentation/widgets/language_snack_content.dart';
import 'package:flutter/material.dart';

class SnackTomatoBasket extends StatefulWidget {
  const SnackTomatoBasket({
    required this.basket,
    required this.onBite,
    this.onInteractionChanged,
    super.key,
  });

  final DailySnackBasket basket;
  final LanguageSnack? Function() onBite;
  final ValueChanged<bool>? onInteractionChanged;

  static const assetRoot = 'assets/images/snack_tomato/';
  static const stages = [
    'origin_tomato.png',
    '1_bite_tomato.png',
    '2_bite_tomato.png',
    '3_bite_tomato.png',
    'last_tomato.png',
  ];
  static const basketStages = [
    'tomato_basket.png',
    'tomato_basket_leave_2.png',
    'tomato_basket_leave_1.png',
    'tomato_basket_leave_0.png',
  ];

  @override
  State<SnackTomatoBasket> createState() => _SnackTomatoBasketState();
}

class _SnackTomatoBasketState extends State<SnackTomatoBasket>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late bool _opened =
      widget.basket.consumed % DailySnackBasket.bitesPerTomato != 0;
  bool _busy = false;
  bool _opening = false;
  bool _precached = false;
  int? _displayBites;
  int? _displayTomato;
  DialogRoute<void>? _dialog;
  NavigatorState? _navigator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final file in [
        ...SnackTomatoBasket.stages,
        ...SnackTomatoBasket.basketStages,
      ]) {
        precacheImage(
          ResizeImage(
            AssetImage('${SnackTomatoBasket.assetRoot}$file'),
            width: 768,
          ),
          context,
        );
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    final route = _dialog;
    final navigator = _navigator;
    if (route != null && navigator != null) {
      // 계정·언어 변경으로 Home이 교체되면 이전 콘텐츠 팝업도 닫아요.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
    }
    super.dispose();
  }

  Future<void> _openTomato() async {
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _opened = true);
      return;
    }
    _motion.duration = const Duration(milliseconds: 400);
    setState(() {
      _opening = true;
      _busy = true;
    });
    widget.onInteractionChanged?.call(true);
    try {
      await _motion.forward(from: 0).orCancel;
      if (mounted) _opened = true;
    } on TickerCanceled {
      // 화면을 떠나면 꺼내기도 취소하며 소비 횟수는 바꾸지 않아요.
    } finally {
      if (mounted) {
        _motion.reset();
        setState(() {
          _opening = false;
          _busy = false;
        });
        widget.onInteractionChanged?.call(false);
      }
    }
  }

  Future<void> _bite() async {
    if (_busy || widget.basket.isFinished) return;
    if (!_opened) {
      await _openTomato();
      return;
    }
    final consumed = widget.basket.consumed;
    if (consumed >= DailySnackBasket.capacity) return;
    _motion.duration = const Duration(milliseconds: 360);
    setState(() {
      _busy = true;
      _displayBites = consumed % DailySnackBasket.bitesPerTomato;
      _displayTomato = consumed ~/ DailySnackBasket.bitesPerTomato;
    });
    widget.onInteractionChanged?.call(true);
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        await _motion.forward(from: 0).orCancel;
      }
      if (!mounted) return;
      final snack = widget.onBite();
      if (snack == null) return;
      setState(
        () => _displayBites = consumed % DailySnackBasket.bitesPerTomato + 1,
      );
      _motion.reset();
      final route = DialogRoute<void>(
        context: context,
        builder: (context) => _SnackDialog(snack: snack),
      );
      _dialog = route;
      _navigator = Navigator.of(context, rootNavigator: true);
      await _navigator!.push(route);
      _dialog = null;
      if (!mounted) return;
    } on TickerCanceled {
      // 화면을 떠난 경우 더 이상 팝업을 열지 않아요.
    } finally {
      if (mounted) {
        _motion.reset();
        setState(() {
          if (_displayBites == DailySnackBasket.bitesPerTomato) {
            _opened = false;
          }
          _busy = false;
          _displayBites = null;
          _displayTomato = null;
        });
        widget.onInteractionChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final consumed = widget.basket.consumed;
    final finished = widget.basket.isFinished;
    final enabled = !_busy && !finished;
    final basketAsset = SnackTomatoBasket
        .basketStages[consumed ~/ DailySnackBasket.bitesPerTomato];
    final ink = Theme.of(context).colorScheme.onSurface;
    final tomato = _displayTomato ?? math.min(consumed ~/ 4, 2);
    final bites = _displayBites ?? (consumed == 12 ? 4 : consumed % 4);
    final label = finished
        ? '${copy.snackBasketFinished}. ${copy.snackBasketNextDay}'
        : _opened
        ? copy.snackTomatoLabel(tomato + 1, 4 - bites)
        : copy.openSnackBasket;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$consumed / 12',
            style: AppTypography.captionMono.copyWith(letterSpacing: 0),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: _opened
                    ? Row(
                        children: [
                          if (!finished)
                            IconButton(
                              tooltip: copy.snackBasketTooltip,
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _opened = false),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: ink,
                                disabledForegroundColor: Theme.of(
                                  context,
                                ).disabledColor,
                              ),
                              icon: const Icon(
                                Icons.shopping_basket_outlined,
                                size: 20,
                              ),
                            ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.md,
                            ),
                            child: Text(
                              '${tomato + 1} / 3',
                              style: AppTypography.captionMono.copyWith(
                                color: ink,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              Center(
                child: SizedBox.square(
                  dimension: 220,
                  child: Semantics(
                    button: true,
                    enabled: enabled,
                    label: label,
                    onTap: enabled ? _bite : null,
                    excludeSemantics: true,
                    child: Tooltip(
                      message: label,
                      child: InkWell(
                        key: const ValueKey('snack-tomato-touch'),
                        excludeFromSemantics: true,
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        onTap: enabled ? _bite : null,
                        child: AnimatedBuilder(
                          animation: _motion,
                          builder: (context, _) {
                            final t = _motion.value;
                            if (_opening) {
                              return _TomatoPickup(
                                key: const ValueKey('tomato-pickup'),
                                progress: t,
                                basketAsset: basketAsset,
                                tomatoAsset: SnackTomatoBasket.stages[bites],
                              );
                            }
                            final scale = t < .35
                                ? 1 - .08 * (t / .35)
                                : .92 +
                                      .08 *
                                          Curves.easeOutBack.transform(
                                            (t - .35) / .65,
                                          );
                            final stage = _busy && t >= .35
                                ? math.min(bites + 1, 4)
                                : bites;
                            return Transform.scale(
                              scale: scale,
                              child: Transform.rotate(
                                angle: math.sin(t * math.pi * 2) * .035,
                                child: Image.asset(
                                  '${SnackTomatoBasket.assetRoot}${_opened ? SnackTomatoBasket.stages[stage] : basketAsset}',
                                  key: ValueKey(
                                    'tomato-stage-${_opened ? stage : 'basket'}',
                                  ),
                                  fit: BoxFit.contain,
                                  cacheWidth: 768,
                                  gaplessPlayback: true,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (finished && !_busy)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    children: [
                      Text(
                        copy.snackBasketFinished,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm,
                      ),
                      Text(
                        copy.snackBasketNextDay,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TomatoPickup extends StatelessWidget {
  const _TomatoPickup({
    required this.progress,
    required this.basketAsset,
    required this.tomatoAsset,
    super.key,
  });

  final double progress;
  final String basketAsset;
  final String tomatoAsset;

  @override
  Widget build(BuildContext context) {
    final travel = Curves.easeOutCubic.transform(progress);
    final scale = .42 + .58 * Curves.easeOutBack.transform(progress);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity:
              1 -
              const Interval(0, .7, curve: Curves.easeOut).transform(progress),
          child: Transform.translate(
            offset: Offset(0, 12 * travel),
            child: Image.asset(
              '${SnackTomatoBasket.assetRoot}$basketAsset',
              fit: BoxFit.contain,
              cacheWidth: 768,
              excludeFromSemantics: true,
            ),
          ),
        ),
        Opacity(
          opacity: const Interval(
            0,
            .18,
            curve: Curves.easeOut,
          ).transform(progress),
          child: Transform.translate(
            key: const ValueKey('tomato-pickup-offset'),
            offset: Offset(24 * (1 - travel), 30 * (1 - travel)),
            child: Transform.scale(
              key: const ValueKey('tomato-pickup-scale'),
              scale: scale,
              child: Image.asset(
                '${SnackTomatoBasket.assetRoot}$tomatoAsset',
                fit: BoxFit.contain,
                cacheWidth: 768,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SnackDialog extends StatelessWidget {
  const _SnackDialog({required this.snack});
  final LanguageSnack snack;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: switch (snack.contentType) {
      'usage_contrast' => AppPalette.blockBlue,
      'homonym' => AppPalette.blockLimeSoft,
      _ => AppPalette.blockLilac,
    },
    insetPadding: const EdgeInsets.all(AppSpacing.md),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: const ValueKey('close-snack'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: LanguageSnackContent(snack: snack),
            ),
          ),
        ],
      ),
    ),
  );
}
