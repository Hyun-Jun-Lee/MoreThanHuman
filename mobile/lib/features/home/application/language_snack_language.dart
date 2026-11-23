import 'package:curitalk/features/home/application/snack_account_scope.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final languageSnackLanguageProvider = Provider<String>((ref) {
  final configured = ref.watch(snackAccountScopeProvider);
  if (configured != null) return configured.language;
  return ref
          .watch(authControllerProvider)
          .value
          ?.user
          ?.language
          .targetLanguage
          .code ??
      'en';
});
