import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/data/api_language_snack_repository.dart';
import 'package:curitalk/features/home/data/language_snack_cache.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageSnacksController extends AsyncNotifier<List<LanguageSnack>> {
  @override
  Future<List<LanguageSnack>> build() async {
    if (!ref.watch(languageSnacksEnabledProvider)) {
      return const <LanguageSnack>[];
    }

    final LanguageSnackCache cache = ref.watch(languageSnackCacheProvider);
    try {
      final List<LanguageSnack> snacks = await ref
          .watch(languageSnackRepositoryProvider)
          .listPublished();
      try {
        await cache.write(snacks);
      } on Object {
        // A storage failure should not hide a valid network response.
      }
      return snacks;
    } on Object {
      try {
        return await cache.read() ?? const <LanguageSnack>[];
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
