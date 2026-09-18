import 'dart:async';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/application/daily_snack_basket_controller.dart';
import 'package:curitalk/features/home/presentation/widgets/snack_tomato_basket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageSnackHomeSection extends ConsumerStatefulWidget {
  const LanguageSnackHomeSection({super.key});
  @override
  ConsumerState<LanguageSnackHomeSection> createState() =>
      _LanguageSnackHomeSectionState();
}

class _LanguageSnackHomeSectionState
    extends ConsumerState<LanguageSnackHomeSection>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  bool _interacting = false;
  String? _scope;

  void _checkDay() {
    if (!mounted || _interacting) return;
    ref.read(dailySnackBasketProvider.notifier).ensureToday();
    _midnightTimer?.cancel();
    final now = ref.read(snackClockProvider)();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now), _checkDay);
  }

  void _interactionChanged(bool active) {
    _interacting = active;
    if (!active) _checkDay();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleMicrotask(() {
      if (mounted) {
        ref.read(languageSnacksControllerProvider.notifier).refreshIfStale();
        _checkDay();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(languageSnacksControllerProvider.notifier).refreshIfStale();
      _checkDay();
    } else {
      _midnightTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageSnackLanguageProvider);
    final userId = ref.watch(snackUserIdProvider);
    final scope = '$userId.$language';
    if (_scope != scope) {
      _scope = scope;
      _interacting = false;
      scheduleMicrotask(_checkDay);
    }
    ref.listen(languageSnacksControllerProvider, (_, next) {
      if (!next.isLoading &&
          next.value?.isNotEmpty == true &&
          ref.read(dailySnackBasketProvider).value == null) {
        ref.read(dailySnackBasketProvider.notifier).ensureToday();
      }
    });
    final value = ref.watch(dailySnackBasketProvider);
    final basket = value.value;
    if (value.isLoading ||
        userId == null ||
        basket == null ||
        basket.snacks.any((snack) => snack.contentLanguage != language)) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SnackTomatoBasket(
          key: ValueKey('$userId.$language.${basket.day}'),
          basket: basket,
          onBite: () => ref.read(dailySnackBasketProvider.notifier).takeBite(),
          onInteractionChanged: _interactionChanged,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
      ],
    );
  }
}
