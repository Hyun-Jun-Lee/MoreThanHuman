import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/billing/billing_controller.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:curitalk/features/billing/paywall_screen.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
import 'package:curitalk/features/conversation/domain/conversation_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() {
  test('decodes account balances', () {
    final value = BillingEntitlement.fromJson({
      'plan': 'member',
      'status': 'active',
      'slot_limit': 4,
      'remaining_turns': 17,
      'trial_turns': 7,
      'paid_turns': 10,
    });
    expect(value.slotLimit, 4);
    expect(value.remainingTurns, 17);
    expect(value.trialTurns, 7);
    expect(value.paidTurns, 10);
  });

  Future<void> showStore(
    WidgetTester tester,
    _TestBillingController controller, {
    String? purpose,
    bool admin = false,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billingControllerProvider.overrideWith(() => controller),
          billingEntitlementProvider.overrideWith(
            (ref) async => BillingEntitlement(
              plan: admin ? 'admin' : 'member',
              status: 'active',
              slotLimit: 4,
              remainingTurns: 17,
              trialTurns: 7,
              paidTurns: 10,
              isAdmin: admin,
              isUnlimited: admin,
            ),
          ),
          conversationAccessProvider.overrideWith(
            (ref) async => const ConversationAccess(
              enabled: true,
              canCreate: true,
              usedSlots: 2,
              slotLimit: 4,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PaywallScreen(purpose: purpose),
        ),
      ),
    );
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets(
    'shows balances and separate repeat-purchase products without restore',
    (tester) async {
      final controller = _TestBillingController();
      await showStore(tester, controller);
      expect(find.text('남은 대화권 17회'), findsOneWidget);
      expect(find.text('대화창 슬롯 2 / 4개 사용 중'), findsOneWidget);
      expect(find.text('구매 복원'), findsNothing);
      await tester.scrollUntilVisible(find.text('대화창 슬롯 +1개'), 250);
      await tester.tap(find.widgetWithText(FilledButton, '구매').first);
      await tester.pump();
      expect(
        controller.purchases.single,
        'com.morethanhuman.curitalk.slots.plus.1',
      );
      await tester.tap(find.widgetWithText(FilledButton, '구매').first);
      expect(controller.purchases.length, 2);
      await tester.scrollUntilVisible(find.text('대화권 20회 충전'), 250);
      expect(find.text('대화권 5회 충전'), findsOneWidget);
      expect(find.text('대화권 10회 충전'), findsOneWidget);
    },
  );

  testWidgets('turn shortage focuses reply section', (tester) async {
    await showStore(tester, _TestBillingController(), purpose: 'buy_turns');
    expect(find.text('대화권 충전').hitTestable(), findsOneWidget);
  });

  testWidgets('admins cannot purchase', (tester) async {
    await showStore(tester, _TestBillingController(), admin: true);
    await tester.scrollUntilVisible(find.text('대화창 슬롯 +1개'), 250);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '구매').first)
          .onPressed,
      isNull,
    );
  });
}

class _TestBillingController extends BillingController {
  final purchases = <String>[];
  @override
  BillingUiState build() => BillingUiState(
    products: [
      for (final id in BillingController.productIds)
        ProductDetails(
          id: id,
          title: id,
          description: '',
          price: '₩1,000',
          rawPrice: 1000,
          currencyCode: 'KRW',
        ),
    ],
  );
  @override
  Future<void> loadProducts() async {}
  @override
  Future<void> purchase(ProductDetails product) async {
    purchases.add(product.id);
  }
}
