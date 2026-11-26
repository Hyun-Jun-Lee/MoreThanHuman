import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:curitalk/features/billing/billing_controller.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.purpose});
  final String? purpose;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final _slotsKey = GlobalKey();
  final _turnsKey = GlobalKey();
  bool _focused = false;
  String _selectedProductId = 'com.morethanhuman.curitalk.slots.plus.1';

  bool get _supportsPurchases =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_supportsPurchases) {
      Future<void>.microtask(
        () => ref.read(billingControllerProvider.notifier).loadProducts(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ko = AppCopy.of(context).isKorean;
    final state = ref.watch(billingControllerProvider);
    final balance = ref.watch(billingEntitlementProvider);
    final products = [...state.products]
      ..sort(
        (a, b) => int.parse(
          a.id.split('.').last,
        ).compareTo(int.parse(b.id.split('.').last)),
      );
    final busy =
        state.isProcessing ||
        (state.message == 'verified' && balance.isLoading);
    final selected = state.products
        .where((p) => p.id == _selectedProductId)
        .firstOrNull;
    final canPurchase =
        _supportsPurchases &&
        !busy &&
        !balance.isLoading &&
        !balance.hasError &&
        balance.asData?.value != null &&
        balance.asData?.value.isUnlimited != true;
    if (!_focused && state.products.isNotEmpty && widget.purpose != null) {
      _focused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = (widget.purpose == 'buy_slots' ? _slotsKey : _turnsKey)
            .currentContext;
        if (target != null) Scrollable.ensureVisible(target);
      });
    }
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(ko ? '대화 상점' : 'Conversation store')),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_supportsPurchases)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('store-purchase'),
                      onPressed: canPurchase && selected != null
                          ? () => ref
                                .read(billingControllerProvider.notifier)
                                .purchase(selected)
                          : null,
                      child: Text(
                        selected == null
                            ? (ko ? '상품을 선택해 주세요' : 'Select a product')
                            : (ko
                                  ? '${selected.price} 구매'
                                  : 'Buy · ${selected.price}'),
                      ),
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => launchUrl(Uri.parse(AppConfig.termsOfUseUrl)),
                      child: Text(ko ? '이용약관' : 'Terms of Use'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => launchUrl(
                              Uri.parse(
                                AppConfig.privacyPolicyUrlFor(isKorean: ko),
                              ),
                            ),
                      child: Text(ko ? '개인정보처리방침' : 'Privacy Policy'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(24),
              children: [
                balance.when(
                  data: (value) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ko ? '대화창 슬롯' : 'Conversation slots',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${value.isUnlimited ? '∞' : (value.slotLimit ?? '—')}${ko ? '개' : ''}',
                                  key: const ValueKey('store-slot-balance'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ko ? '남은 대화권' : 'Credits remaining',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${value.isUnlimited ? '∞' : (value.remainingTurns ?? '—')}${ko ? '회' : ''}',
                                  key: const ValueKey('store-turn-balance'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(billingEntitlementProvider),
                    child: Text(ko ? '잔액 다시 확인' : 'Retry balance'),
                  ),
                ),
                if (!_supportsPurchases)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      ko
                          ? '구매는 iOS 앱에서 이용할 수 있어요.'
                          : 'Purchases are available on iOS.',
                    ),
                  ),
                if (_supportsPurchases) ...[
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  for (final kind in ['slots', 'turns'])
                    Column(
                      key: kind == 'slots' ? _slotsKey : _turnsKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        Text(
                          kind == 'slots'
                              ? (ko ? '대화창 슬롯 추가' : 'Add conversation slots')
                              : (ko ? '대화권 충전' : 'Conversation credits'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        for (final product in products.where(
                          (p) => p.id.contains('.$kind.'),
                        ))
                          Semantics(
                            selected: product.id == _selectedProductId,
                            child: Card(
                              key: ValueKey('store-product-${product.id}'),
                              color: product.id == _selectedProductId
                                  ? AppPalette.subscriptionSelected
                                  : null,
                              child: ListTile(
                                enabled: canPurchase,
                                onTap: canPurchase
                                    ? () => setState(
                                        () => _selectedProductId = product.id,
                                      )
                                    : null,
                                title: Text(
                                  kind == 'slots'
                                      ? (ko
                                            ? '대화창 슬롯 +${product.id.split('.').last}개'
                                            : 'Conversation slots +${product.id.split('.').last}')
                                      : (ko
                                            ? '대화권 ${product.id.split('.').last}회 충전'
                                            : '${product.id.split('.').last} conversation credits'),
                                ),
                                subtitle: Text(product.price),
                                trailing: product.id == _selectedProductId
                                    ? Image.asset(
                                        'assets/images/snack_tomato/origin_tomato.png',
                                        key: const ValueKey(
                                          'store-selected-tomato',
                                        ),
                                        width: 36,
                                        height: 36,
                                        excludeFromSemantics: true,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (state.message != null && state.message != 'verified')
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        state.message == 'account_conflict'
                            ? (ko
                                  ? '원래 구매한 계정으로 로그인해서 다시 시도해 주세요.'
                                  : 'Sign in to the original purchasing account and try again.')
                            : (ko
                                  ? '구매가 완료되지 않았어요. 잔액을 확인하고 다시 시도해 주세요.'
                                  : 'Purchase not completed. Check your balance and try again.'),
                      ),
                    ),
                  if (state.products.isEmpty && !state.isLoading)
                    TextButton(
                      onPressed: () => ref
                          .read(billingControllerProvider.notifier)
                          .loadProducts(),
                      child: Text(ko ? '상품 다시 불러오기' : 'Reload products'),
                    ),
                ],
              ],
            ),
            if (busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              ko
                                  ? '구매와 잔액을 확인하고 있어요'
                                  : 'Verifying purchase and balance',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
