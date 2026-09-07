import 'dart:convert';

import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class LanguageSnackCache {
  Future<List<LanguageSnack>?> read();

  Future<void> write(List<LanguageSnack> snacks);
}

class SecureLanguageSnackCache implements LanguageSnackCache {
  const SecureLanguageSnackCache(this.backend);

  static const String storageKey = 'curitalk.language_snacks';

  final SecureStorageBackend backend;

  @override
  Future<List<LanguageSnack>?> read() async {
    final String? encoded = await backend.read(storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List) {
        throw const FormatException('Language snack cache is not a list.');
      }
      return List<LanguageSnack>.unmodifiable(
        decoded.cast<Object?>().map(LanguageSnack.fromJson),
      );
    } on Object {
      try {
        await backend.delete(storageKey);
      } on Object {
        // Cache cleanup must not block the rest of Home.
      }
      return null;
    }
  }

  @override
  Future<void> write(List<LanguageSnack> snacks) {
    return backend.write(
      storageKey,
      jsonEncode(
        snacks
            .map((LanguageSnack snack) => snack.toJson())
            .toList(growable: false),
      ),
    );
  }
}

final Provider<LanguageSnackCache> languageSnackCacheProvider =
    Provider<LanguageSnackCache>((Ref ref) {
      return SecureLanguageSnackCache(ref.watch(secureStorageBackendProvider));
    });
