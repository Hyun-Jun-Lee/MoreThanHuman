import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

abstract interface class AppleIdentityService {
  Future<AppleIdentityTokens?> signIn();
}

class AppleIdentityTokens {
  const AppleIdentityTokens({required this.idToken, required this.rawNonce});

  final String idToken;
  final String rawNonce;
}

class AppleSignInIdentityService implements AppleIdentityService {
  AppleSignInIdentityService({
    String Function()? nonceGenerator,
    Future<AuthorizationCredentialAppleID> Function(String nonce)?
    requestCredential,
  }) : _nonceGenerator = nonceGenerator ?? generateNonce,
       _requestCredential = requestCredential ?? _requestAppleCredential;

  final String Function() _nonceGenerator;
  final Future<AuthorizationCredentialAppleID> Function(String nonce)
  _requestCredential;

  static Future<AuthorizationCredentialAppleID> _requestAppleCredential(
    String nonce,
  ) {
    return SignInWithApple.getAppleIDCredential(
      scopes: <AppleIDAuthorizationScopes>[
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
  }

  @override
  Future<AppleIdentityTokens?> signIn() async {
    final String rawNonce = _nonceGenerator();
    final String hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final AuthorizationCredentialAppleID credential =
          await _requestCredential(hashedNonce);
      final String? idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppleIdentityException(
          'Apple did not return an identity token.',
        );
      }
      return AppleIdentityTokens(idToken: idToken, rawNonce: rawNonce);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw AppleIdentityException(error.message);
    } on SignInWithAppleException catch (error) {
      throw AppleIdentityException(error.toString());
    }
  }
}

class AppleIdentityException implements Exception {
  const AppleIdentityException(this.message);

  final String message;

  @override
  String toString() => message;
}

final Provider<AppleIdentityService> appleIdentityServiceProvider =
    Provider<AppleIdentityService>((Ref ref) {
      return AppleSignInIdentityService();
    });
