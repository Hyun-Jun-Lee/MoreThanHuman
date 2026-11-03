import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:curitalk/features/auth/data/apple_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  test(
    'sends hashed nonce to Apple and returns raw nonce for Supabase',
    () async {
      String? nonceSentToApple;
      final AppleSignInIdentityService service = AppleSignInIdentityService(
        nonceGenerator: () => 'unique-raw-nonce',
        requestCredential: (String nonce) async {
          nonceSentToApple = nonce;
          return const AuthorizationCredentialAppleID(
            userIdentifier: 'apple-user',
            givenName: null,
            familyName: null,
            authorizationCode: 'auth-code',
            email: null,
            identityToken: 'apple-id-token',
            state: null,
          );
        },
      );

      final AppleIdentityTokens? tokens = await service.signIn();

      expect(
        nonceSentToApple,
        sha256.convert(utf8.encode('unique-raw-nonce')).toString(),
      );
      expect(tokens?.rawNonce, 'unique-raw-nonce');
      expect(tokens?.idToken, 'apple-id-token');
    },
  );

  test('canceling Apple authorization leaves sign-in untouched', () async {
    final AppleSignInIdentityService service = AppleSignInIdentityService(
      nonceGenerator: () => 'another-nonce',
      requestCredential: (_) async =>
          throw const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.canceled,
            message: 'Canceled',
          ),
    );

    expect(await service.signIn(), isNull);
  });
}
