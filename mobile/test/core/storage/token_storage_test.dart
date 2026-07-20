import 'package:curitalk/core/storage/storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthTokens', () {
    test('parses the backend token response', () {
      final AuthTokens tokens = AuthTokens.fromJson(<String, dynamic>{
        'access_token': 'access-token',
        'refresh_token': 'refresh-token',
        'token_type': 'bearer',
      });

      expect(tokens.accessToken, 'access-token');
      expect(tokens.refreshToken, 'refresh-token');
      expect(tokens.tokenType, 'bearer');
    });

    test('rejects incomplete token payloads', () {
      expect(
        () => AuthTokens.fromJson(<String, dynamic>{
          'access_token': 'access-token',
        }),
        throwsFormatException,
      );
    });
  });

  group('SecureTokenStorage', () {
    test(
      'stores and clears one token pair without deleting device id',
      () async {
        final _MemorySecureStorage backend = _MemorySecureStorage();
        final SecureTokenStorage storage = SecureTokenStorage(backend);
        const AuthTokens tokens = AuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );

        await storage.writeDeviceId(' installation-id ');
        await storage.writeTokens(tokens);

        expect((await storage.readTokens())?.accessToken, 'access-token');
        expect(await storage.readAccessToken(), 'access-token');
        expect(await storage.readDeviceId(), 'installation-id');

        await storage.clearTokens();

        expect(await storage.readTokens(), isNull);
        expect(await storage.readDeviceId(), 'installation-id');
      },
    );

    test('removes a corrupted token payload', () async {
      final _MemorySecureStorage backend = _MemorySecureStorage();
      final SecureTokenStorage storage = SecureTokenStorage(backend);
      backend.values['curitalk.auth_tokens'] = 'not-json';

      expect(await storage.readTokens(), isNull);
      expect(backend.values.containsKey('curitalk.auth_tokens'), isFalse);
    });

    test('rejects invalid installation ids', () async {
      final SecureTokenStorage storage = SecureTokenStorage(
        _MemorySecureStorage(),
      );

      await expectLater(storage.writeDeviceId('  '), throwsArgumentError);
      await expectLater(storage.writeDeviceId('a' * 65), throwsArgumentError);
    });
  });

  group('InstallationIdService', () {
    test('creates and reuses one installation UUID', () async {
      final SecureTokenStorage storage = SecureTokenStorage(
        _MemorySecureStorage(),
      );
      int generationCount = 0;
      final InstallationIdService service = InstallationIdService(
        storage,
        generateId: () {
          generationCount += 1;
          return '550e8400-e29b-41d4-a716-446655440000';
        },
      );

      expect(
        await service.getOrCreate(),
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(
        await service.getOrCreate(),
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(generationCount, 1);
    });
  });
}

class _MemorySecureStorage implements SecureStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
