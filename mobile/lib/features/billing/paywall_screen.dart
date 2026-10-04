import 'dart:io';

import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/config/app_config.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/billing/billing_controller.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(billingControllerProvider.notifier).loadProducts(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final state = ref.watch(billingControllerProvider);
    final entitlement = ref.watch(billingEntitlementProvider);
    if (!Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(title: Text(copy.subscriptionTitle)),
        body: Center(child: Text(copy.purchaseIosOnly)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(copy.subscriptionTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text(copy.subscriptionIntro, style: AppTypography.headlineMd),
            const SizedBox(height: AppSpacing.md),
            entitlement.when(
              data: (value) => Text(copy.currentPlan(value.plan)),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(copy.subscriptionStatusUnavailable),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (state.isLoading && state.products.isEmpty)
              const Center(child: CircularProgressIndicator()),
            for (final id in const ['Advance', 'Plus'])
              _PlanCard(
                id: id,
                product: state.products
                    .where((item) => item.id == id)
                    .firstOrNull,
                busy: state.isProcessing,
                onBuy: (product) => ref
                    .read(billingControllerProvider.notifier)
                    .purchase(product),
              ),
            if (state.message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                copy.billingMessage(state.message!),
                style: AppTypography.bodySm,
              ),
            ],
            if (state.products.isEmpty && !state.isLoading)
              TextButton(
                onPressed: () =>
                    ref.read(billingControllerProvider.notifier).loadProducts(),
                child: Text(copy.retryLabel),
              ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: state.isProcessing
                  ? null
                  : () =>
                        ref.read(billingControllerProvider.notifier).restore(),
              child: Text(copy.restorePurchases),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://apps.apple.com/account/subscriptions'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(copy.manageSubscription),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(copy.subscriptionDisclosure, style: AppTypography.bodySm),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.subscriptionTermsUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(copy.termsOfUse),
                ),
                TextButton(
                  onPressed: AppConfig.privacyPolicyUrl.isEmpty
                      ? null
                      : () => launchUrl(
                          Uri.parse(AppConfig.privacyPolicyUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                  child: Text(copy.privacyPolicy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.id,
    required this.product,
    required this.busy,
    required this.onBuy,
  });
  final String id;
  final ProductDetails? product;
  final bool busy;
  final ValueChanged<ProductDetails> onBuy;

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isPlus = id == 'Plus';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(id, style: AppTypography.headlineMd),
            const SizedBox(height: AppSpacing.xs),
            Text(copy.planBenefits(isPlus), style: AppTypography.bodySm),
            const SizedBox(height: AppSpacing.md),
            Text(
              product == null
                  ? copy.priceUnavailable
                  : copy.monthlyPrice(product!.price),
              style: AppTypography.button,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed:
                  busy || product == null || AppConfig.privacyPolicyUrl.isEmpty
                  ? null
                  : () => onBuy(product!),
              child: Text(copy.subscribeTo(id)),
            ),
          ],
        ),
      ),
    );
  }
}
