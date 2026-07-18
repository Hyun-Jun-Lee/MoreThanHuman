import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() => _errorMessage = null);
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
      _showError(error.message);
    } on ApiException catch (error) {
      debugPrint('CuritalkAuth login screen ApiException: $error');
      if (!ref.read(authControllerProvider).hasError) {
        await _signOutGoogleSafely();
      }
      _showError(error.message);
    } on Object catch (error, stackTrace) {
      debugPrint('CuritalkAuth login screen unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showError('Sign-in could not be completed. Please try again.');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
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
    return AppScaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('CURITALK', style: AppTypography.headlineMd),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Practice English with your own topics.',
              style: AppTypography.displayLg,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Build fluency by discussing what actually matters to you. Your interests lead the conversation.',
              style: AppTypography.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: auth.hasError ? 'TRY AGAIN' : 'CONTINUE WITH GOOGLE',
              leading: const _GoogleMark(),
              isLoading: auth.isLoading,
              onPressed: _signIn,
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: AppTypography.bodySm.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const AppColorBlockCard(
              color: AppPalette.blockPink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Your topics', style: AppTypography.headlineMd),
                  SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      Chip(label: Text('GLOBAL NEWS')),
                      Chip(label: Text('TRAVEL')),
                      Chip(label: Text('BASEBALL')),
                      Chip(label: Text('TECHNOLOGY')),
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
