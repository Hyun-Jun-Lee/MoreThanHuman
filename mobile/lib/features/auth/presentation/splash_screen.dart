import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthSession> auth = ref.watch(authControllerProvider);
    final AsyncValue<bool> onboarding = ref.watch(onboardingControllerProvider);
    final bool hasError = auth.hasError || onboarding.hasError;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'CURITALK',
                  style: AppTypography.displayLg.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Speak about anything.',
                  style: AppTypography.labelMono.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (hasError)
                  OutlinedButton(
                    onPressed: () {
                      ref.invalidate(authControllerProvider);
                      ref.invalidate(onboardingControllerProvider);
                    },
                    child: const Text('Try again'),
                  )
                else
                  const SizedBox.square(
                    dimension: AppSize.icon,
                    child: CircularProgressIndicator(
                      strokeWidth: AppBorderWidth.focused,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
