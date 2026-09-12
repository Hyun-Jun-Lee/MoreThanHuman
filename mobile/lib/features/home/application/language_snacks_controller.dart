import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/data/api_language_snack_repository.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';

class LanguageSnacksController extends AsyncNotifier<List<LanguageSnack>> {
  DateTime? _lastFetch;

  void refreshIfStale() {
    if (state.isLoading) return;
    if (_lastFetch == null ||
        DateTime.now().difference(_lastFetch!) >= const Duration(minutes: 5)) {
      ref.invalidateSelf();
    }
  }

  @override
  Future<List<LanguageSnack>> build() async {
    if (!ref.watch(languageSnacksEnabledProvider)) {
      return const <LanguageSnack>[];
    }
    final String language = ref.watch(languageSnackLanguageProvider);
    bool active = true;
    ref.onDispose(() => active = false);

    final LanguageSnackCache cache = ref.watch(languageSnackCacheProvider);
    try {
      final List<LanguageSnack> snacks = await ref
          .watch(languageSnackRepositoryProvider)
          .listPublished();
      if (!active) return const <LanguageSnack>[];
      if (snacks.any((snack) => snack.contentLanguage != language)) {
        throw const FormatException(
          'Response contains a different learning language.',
        );
      }
      _lastFetch = DateTime.now();
      try {
        await cache.write(snacks);
      } on Object {
        // A storage failure should not hide a valid network response.
      }
      return snacks;
    } on Object {
      try {
        if (!active) return const <LanguageSnack>[];
        return (await cache.read() ?? const <LanguageSnack>[])
            .where((snack) => snack.contentLanguage == language)
            .toList(growable: false);
      } on Object {
        return const <LanguageSnack>[];
      }
    }
  }
}

final Provider<bool> languageSnacksEnabledProvider = Provider<bool>((Ref ref) {
  return ref.watch(authControllerProvider).value?.isAuthenticated ?? false;
});

final AsyncNotifierProvider<LanguageSnacksController, List<LanguageSnack>>
languageSnacksControllerProvider =
    AsyncNotifierProvider<LanguageSnacksController, List<LanguageSnack>>(
      LanguageSnacksController.new,
    );
