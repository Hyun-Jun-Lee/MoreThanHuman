import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashMotionController extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}

final NotifierProvider<SplashMotionController, bool>
splashMotionCompletedProvider = NotifierProvider<SplashMotionController, bool>(
  SplashMotionController.new,
);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _animationStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.96,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 70,
      ),
    ]).animate(_controller);
    _controller.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(splashMotionCompletedProvider.notifier).complete();
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_animationStarted) {
      _animationStarted = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppCopy copy = AppCopy.of(context);
    final AsyncValue<AuthSession> auth = ref.watch(authControllerProvider);
    final AsyncValue<bool> onboarding = ref.watch(onboardingControllerProvider);
    final bool hasError = auth.hasError || onboarding.hasError;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            ScaleTransition(
              scale: _scale,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Image.asset(
                    'assets/images/splash/toma_talk.png',
                    width: double.infinity,
                    fit: BoxFit.contain,
                    semanticLabel: 'Toma Talk',
                  ),
                ),
              ),
            ),
            if (hasError)
              Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  tooltip: copy.tryAgainLabel,
                  onPressed: () {
                    ref.invalidate(authControllerProvider);
                    ref.invalidate(onboardingControllerProvider);
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
