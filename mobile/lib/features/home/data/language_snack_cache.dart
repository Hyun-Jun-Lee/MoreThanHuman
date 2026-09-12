import 'dart:convert';

import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/application/language_snack_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class LanguageSnackCache {
  Future<List<LanguageSnack>?> read();

  Future<void> write(List<LanguageSnack> snacks);
}

class SecureLanguageSnackCache implements LanguageSnackCache {
  const SecureLanguageSnackCache(this.backend, {this.contentLanguage = 'en'});

  static const String legacyKey = 'curitalk.language_snacks';
  final String contentLanguage;
  String get storageKey =>
      'curitalk.language_snacks.v2.$contentLanguage.${contentLanguage == 'en' ? 'ko' : 'en'}';

  final SecureStorageBackend backend;

  @override
  Future<List<LanguageSnack>?> read() async {
    await _clearLegacy();
    final String? encoded = await backend.read(storageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! List) {
        throw const FormatException('Language snack cache is not a list.');
      }
      final snacks = decoded
          .cast<Object?>()
          .map(LanguageSnack.fromJson)
          .toList();
      if (snacks.any((snack) => snack.contentLanguage != contentLanguage)) {
        throw const FormatException('Cache language does not match.');
      }
      return List<LanguageSnack>.unmodifiable(snacks);
    } on Object {
      try {
        await backend.delete(storageKey);
      } on Object {
        // Cache cleanup must not block the rest of Home.
      }
      return null;
    }
  }

  Future<void> _clearLegacy() async {
    try {
      await backend.delete(legacyKey);
    } on Object {
      // 이전 버전 캐시 삭제 실패는 새 목록 사용을 막지 않아요.
    }
  }

  @override
  Future<void> write(List<LanguageSnack> snacks) async {
    if (snacks.any((snack) => snack.contentLanguage != contentLanguage)) {
      throw const FormatException(
        'Cannot cache a different learning language.',
      );
    }
    await _clearLegacy();
    await backend.write(
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
      return SecureLanguageSnackCache(
        ref.watch(secureStorageBackendProvider),
        contentLanguage: ref.watch(languageSnackLanguageProvider),
      );
    });
