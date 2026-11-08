import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/billing/billing_controller.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:curitalk/features/billing/paywall_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  testWidgets('selects one paid plan and purchases it from one bottom CTA', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingControllerProvider.overrideWith(_TestBillingController.new),
          billingEntitlementProvider.overrideWith(
            (Ref ref) async =>
                const BillingEntitlement(plan: 'free', status: 'free'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ko'),
          supportedLocales: const <Locale>[Locale('ko'), Locale('en')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: const PaywallScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('원하는 만큼 대화를 이어가세요'), findsNothing);
    expect(find.textContaining('현재 플랜:'), findsNothing);
    expect(find.textContaining('동시 대화 5개'), findsOneWidget);
    expect(find.textContaining('동시 대화 10개'), findsOneWidget);
    expect(find.textContaining('발화 무제한'), findsNWidgets(2));
    expect(find.text('Advance 구독하기'), findsNothing);
    expect(find.text('Plus 구독하기'), findsNothing);
    final Finder currentPlanIndicator = find.byKey(
      const ValueKey<String>('paywall-current-plan-indicator'),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('paywall-plan-Free')),
        matching: currentPlanIndicator,
      ),
      findsOneWidget,
    );
    final FadeTransition indicator = tester.widget<FadeTransition>(
      find.ancestor(
        of: currentPlanIndicator,
        matching: find.byType(FadeTransition),
      ),
    );
    final double initialOpacity = indicator.opacity.value;
    await tester.pump(const Duration(milliseconds: 350));
    expect(indicator.opacity.value, isNot(initialOpacity));

    expect(
      tester
          .widget<Card>(
            find.byKey(const ValueKey<String>('paywall-plan-Advance')),
          )
          .color,
      AppPalette.subscriptionSelected,
    );
    expect(
      tester
          .widget<Card>(find.byKey(const ValueKey<String>('paywall-plan-Plus')))
          .color,
      Theme.of(
        tester.element(find.byKey(const ValueKey<String>('paywall-plan-Plus'))),
      ).colorScheme.surfaceContainerLow,
    );

    final Text price = tester.widget<Text>(find.text(r'$4.99'));
    final Text period = tester.widget<Text>(find.text('/월').first);
    expect(price.style?.fontSize, greaterThan(period.style?.fontSize ?? 0));

    await tester.tap(find.byKey(const ValueKey<String>('paywall-plan-Plus')));
    await tester.pump();
    expect(
      tester
          .widget<Card>(
            find.byKey(const ValueKey<String>('paywall-plan-Advance')),
          )
          .color,
      Theme.of(
        tester.element(
          find.byKey(const ValueKey<String>('paywall-plan-Advance')),
        ),
      ).colorScheme.surfaceContainerLow,
    );
    expect(
      tester
          .widget<Card>(find.byKey(const ValueKey<String>('paywall-plan-Plus')))
          .color,
      AppPalette.subscriptionSelected,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('paywall-subscribe')),
      300,
    );
    expect(find.text('이전에 구매했었나요?'), findsOneWidget);
    expect(find.text('구매 복원'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '구독하기'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '구독하기'));
    await tester.pump();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(PaywallScreen)),
    );
    expect(
      (container.read(billingControllerProvider.notifier)
              as _TestBillingController)
          .purchasedProductId,
      'Plus',
    );
    debugDefaultTargetPlatformOverride = null;
  });
}

class _TestBillingController extends BillingController {
  String? purchasedProductId;

  @override
  BillingUiState build() => BillingUiState(
    products: <ProductDetails>[
      ProductDetails(
        id: 'Advance',
        title: 'Advance',
        description: '',
        price: r'$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: 'Plus',
        title: 'Plus',
        description: '',
        price: r'$6.99',
        rawPrice: 6.99,
        currencyCode: 'USD',
      ),
    ],
  );

  @override
  Future<void> loadProducts() async {}

  @override
  Future<void> purchase(ProductDetails product) async {
    purchasedProductId = product.id;
  }
}
