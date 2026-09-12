import 'dart:async';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:curitalk/features/home/application/language_snacks_controller.dart';
import 'package:curitalk/features/home/presentation/widgets/language_snack_carousel.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleMicrotask(() {
      if (mounted) {
        ref.read(languageSnacksControllerProvider.notifier).refreshIfStale();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(languageSnacksControllerProvider.notifier).refreshIfStale();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageSnackLanguageProvider);
    final value = ref.watch(languageSnacksControllerProvider);
    final snacks =
        value.value
            ?.where((item) => item.contentLanguage == language)
            .toList() ??
        [];
    if (snacks.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        LanguageSnackCarousel(key: ValueKey(language), snacks: snacks),
        const SizedBox(height: AppSpacing.sectionGap),
      ],
    );
  }
}
