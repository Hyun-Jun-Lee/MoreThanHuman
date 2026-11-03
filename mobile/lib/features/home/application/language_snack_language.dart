import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final languageSnackLanguageProvider = Provider<String>((ref) {
  return ref
          .watch(authControllerProvider)
          .value
          ?.user
          ?.language
          .targetLanguage
          .code ??
      'en';
});
