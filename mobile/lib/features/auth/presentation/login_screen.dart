import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  LoginFailureReason? _failureReason;
  bool _isSigningIn = false;

  Future<void> _signIn() async {
    if (_isSigningIn) return;
    setState(() {
      _failureReason = null;
      _isSigningIn = true;
    });
    try {
      if (ref.read(authControllerProvider).hasError) {
        await ref.read(authControllerProvider.notifier).restoreSession();
        return;
      }
      final GoogleIdentityTokens? tokens = await ref
          .read(googleIdentityServiceProvider)
          .signIn();
      if (tokens == null) {
        return;
      }
      await ref
          .read(authControllerProvider.notifier)
          .signInWithGoogleTokens(tokens);
    } on GoogleIdentityException catch (error) {
      debugPrint('CuritalkAuth login screen GoogleIdentityException: $error');
      _showFailure(LoginFailureReason.identity);
    } on ApiException catch (error) {
      debugPrint('CuritalkAuth login screen ApiException: $error');
      if (!ref.read(authControllerProvider).hasError) {
        await _signOutGoogleSafely();
      }
      _showFailure(LoginFailureReason.request);
    } on Object catch (error, stackTrace) {
      debugPrint('CuritalkAuth login screen unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showFailure(LoginFailureReason.unknown);
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signInWithApple() async {
    if (_isSigningIn) return;
    setState(() {
      _failureReason = null;
      _isSigningIn = true;
    });
    try {
      if (ref.read(authControllerProvider).hasError) {
        await ref.read(authControllerProvider.notifier).restoreSession();
        return;
      }
      final AppleIdentityTokens? tokens = await ref
          .read(appleIdentityServiceProvider)
          .signIn();
      if (tokens == null) return;
      await ref
          .read(authControllerProvider.notifier)
          .signInWithAppleToken(tokens);
    } on AppleIdentityException catch (error) {
      debugPrint('CuritalkAuth login screen AppleIdentityException: $error');
      _showFailure(LoginFailureReason.appleIdentity);
    } on ApiException catch (error) {
      debugPrint('CuritalkAuth login screen ApiException: $error');
      _showFailure(LoginFailureReason.request);
    } on Object catch (error, stackTrace) {
      debugPrint('CuritalkAuth login screen unexpected Apple error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showFailure(LoginFailureReason.unknown);
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _showFailure(LoginFailureReason reason) {
    if (mounted) {
      setState(() => _failureReason = reason);
    }
  }

  Future<void> _signOutGoogleSafely() async {
    try {
      await ref.read(googleIdentityServiceProvider).signOut();
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthSession> auth = ref.watch(authControllerProvider);
    final AppCopy appCopy = AppCopy.of(context);
    final AppLoginCopy copy = appCopy.login;
    return AppScaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('CURITALK', style: AppTypography.headlineMd),
            const SizedBox(height: AppSpacing.xxl),
            Text(copy.title, style: AppTypography.displayLg),
            const SizedBox(height: AppSpacing.lg),
            Text(
              copy.description,
              style: AppTypography.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: auth.hasError ? copy.tryAgainLabel : copy.googleLabel,
              leading: const _GoogleMark(),
              isLoading: auth.isLoading || _isSigningIn,
              onPressed: auth.isLoading || _isSigningIn ? null : _signIn,
            ),
            if (!kIsWeb &&
                defaultTargetPlatform == TargetPlatform.iOS) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              SignInWithAppleButton(
                text: copy.appleLabel,
                onPressed: auth.isLoading || _isSigningIn
                    ? null
                    : _signInWithApple,
              ),
            ],
            if (_failureReason != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  appCopy.loginFailureMessage(_failureReason!.name),
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            AppColorBlockCard(
              color: AppPalette.blockPink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(copy.topicCardTitle, style: AppTypography.headlineMd),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final String topic in copy.topicChips)
                        Chip(label: Text(topic)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum LoginFailureReason { identity, appleIdentity, request, unknown }

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSize.icon,
      height: AppSize.icon,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xs)),
      ),
      child: Text(
        'G',
        style: AppTypography.captionMono.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
