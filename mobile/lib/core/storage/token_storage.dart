import 'dart:convert';

import 'package:curitalk/core/storage/auth_tokens.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecureStorageBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureStorageBackend implements SecureStorageBackend {
  const FlutterSecureStorageBackend({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

abstract interface class TokenStorage {
  Future<AuthTokens?> readTokens();

  Future<String?> readAccessToken();

  Future<void> writeTokens(AuthTokens tokens);

  Future<void> clearTokens();

  Future<String?> readDeviceId();

  Future<void> writeDeviceId(String deviceId);
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage(this.backend);

  static const String _tokensKey = 'curitalk.auth_tokens';
  static const String _deviceIdKey = 'curitalk.device_id';

  final SecureStorageBackend backend;

  @override
  Future<AuthTokens?> readTokens() async {
    final String? encodedTokens = await backend.read(_tokensKey);
    if (encodedTokens == null || encodedTokens.isEmpty) {
      return null;
    }

    try {
      return AuthTokens.fromJson(jsonDecode(encodedTokens));
    } on FormatException {
      await backend.delete(_tokensKey);
      return null;
    }
  }

  @override
  Future<String?> readAccessToken() async {
    return (await readTokens())?.accessToken;
  }

  @override
  Future<void> writeTokens(AuthTokens tokens) {
    return backend.write(_tokensKey, jsonEncode(tokens.toJson()));
  }

  @override
  Future<void> clearTokens() => backend.delete(_tokensKey);

  @override
  Future<String?> readDeviceId() => backend.read(_deviceIdKey);

  @override
  Future<void> writeDeviceId(String deviceId) async {
    final String normalizedDeviceId = deviceId.trim();
    if (normalizedDeviceId.isEmpty || normalizedDeviceId.length > 64) {
      throw ArgumentError.value(
        deviceId,
        'deviceId',
        'Must contain between 1 and 64 characters.',
      );
    }
    await backend.write(_deviceIdKey, normalizedDeviceId);
  }
}
