import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/billing/billing_controller.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
import 'package:curitalk/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter/foundation.dart';

class CuritalkApp extends ConsumerStatefulWidget {
  const CuritalkApp({super.key});

  @override
  ConsumerState<CuritalkApp> createState() => _CuritalkAppState();
}

class _CuritalkAppState extends ConsumerState<CuritalkApp>
    with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        ref.read(billingControllerProvider.notifier).retryPendingPurchases();
      }
      ref.invalidate(billingEntitlementProvider);
      ref.invalidate(conversationAccessProvider);
      ref.invalidate(conversationTurnAccessProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      ref.watch(billingControllerProvider);
    }
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.value?.isGuest == true && next.value?.isMember == true) {
        final memberId = next.value!.user!.id;
        ref.invalidate(billingEntitlementProvider);
        ref
            .read(billingEntitlementProvider.future)
            .then((balance) {
              if (!mounted ||
                  ref.read(authControllerProvider).value?.user?.id !=
                      memberId) {
                return;
              }
              final ko = next.value?.user?.appLocale == 'ko';
              _messenger.currentState?.showSnackBar(
                SnackBar(
                  content: Text(
                    ko
                        ? '회원 체험 10회는 계정당 한 번 제공되며 게스트 체험과 별개예요. 남은 체험 ${balance.trialTurns}회.'
                        : 'Member trial: 10 replies once per account, separate from guest usage. ${balance.trialTurns} trial replies remain.',
                  ),
                ),
              );
            })
            .catchError((Object _) {});
      }
    });
    final String? profileAppLocale = ref
        .watch(authControllerProvider)
        .value
        ?.user
        ?.appLocale;
    final String? pendingAppLocale = ref
        .watch(onboardingAppLocaleControllerProvider)
        .value;
    final String? appLocale = profileAppLocale ?? pendingAppLocale;
    return MaterialApp.router(
      title: 'tomatalk',
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale('en'), Locale('ko')],
      locale: appLocale == null ? null : Locale(appLocale),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
