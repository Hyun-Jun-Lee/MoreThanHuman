import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/app/theme/app_component_themes.dart';
import 'package:curitalk/core/config/app_config.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/widgets/app_loading_indicator.dart';
import 'package:curitalk/features/billing/billing_controller.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _selectedPlanId = 'Advance';

  bool get _supportsPurchases =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (!_supportsPurchases) return;
    Future<void>.microtask(
      () => ref.read(billingControllerProvider.notifier).loadProducts(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    if (!_supportsPurchases) {
      return Scaffold(
        appBar: AppBar(title: Text(copy.subscriptionTitle)),
        body: Center(child: Text(copy.purchaseIosOnly)),
      );
    }
    final state = ref.watch(billingControllerProvider);
    final entitlement = ref.watch(billingEntitlementProvider);
    final bool isUpdatingSubscription =
        state.isProcessing ||
        (state.message == 'verified' && entitlement.isLoading);
    final ProductDetails? selectedProduct = state.products
        .where((ProductDetails product) => product.id == _selectedPlanId)
        .firstOrNull;
    return PopScope(
      canPop: !isUpdatingSubscription,
      child: Scaffold(
        appBar: AppBar(title: Text(copy.subscriptionTitle)),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  if (state.isLoading && state.products.isEmpty)
                    const Center(child: AppLoadingIndicator(width: 180)),
                  for (final id in const ['Free', 'Advance', 'Plus'])
                    _PlanCard(
                      id: id,
                      isCurrentPlan:
                          id.toLowerCase() ==
                          entitlement.asData?.value.plan.toLowerCase(),
                      isSelected: id == _selectedPlanId,
                      product: state.products
                          .where((item) => item.id == id)
                          .firstOrNull,
                      onSelected: () {
                        if (id == 'Free' || id == _selectedPlanId) return;
                        HapticFeedback.selectionClick();
                        setState(() => _selectedPlanId = id);
                      },
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
                      onPressed: () => ref
                          .read(billingControllerProvider.notifier)
                          .loadProducts(),
                      child: Text(copy.retryLabel),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    key: const ValueKey<String>('paywall-subscribe'),
                    onPressed: state.isProcessing || selectedProduct == null
                        ? null
                        : () => ref
                              .read(billingControllerProvider.notifier)
                              .purchase(selectedProduct),
                    child: Text(copy.subscribeLabel),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        copy.previousPurchasePrompt,
                        style: AppTypography.bodySm,
                      ),
                      TextButton(
                        onPressed: state.isProcessing
                            ? null
                            : () => ref
                                  .read(billingControllerProvider.notifier)
                                  .restore(),
                        child: Text(copy.restorePurchases),
                      ),
                    ],
                  ),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://apps.apple.com/account/subscriptions',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(copy.manageSubscription),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                        style: AppComponentThemes.mutedTextButton,
                        onPressed: () => launchUrl(
                          Uri.parse(AppConfig.subscriptionTermsUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(copy.termsOfUse),
                      ),
                      TextButton(
                        style: AppComponentThemes.mutedTextButton,
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
              if (isUpdatingSubscription)
                _SubscriptionUpdatingOverlay(
                  message: copy.subscriptionUpdating,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionUpdatingOverlay extends StatelessWidget {
  const _SubscriptionUpdatingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      key: const ValueKey<String>('paywall-purchase-loading'),
      child: BlockSemantics(
        child: Semantics(
          liveRegion: true,
          scopesRoute: true,
          explicitChildNodes: true,
          label: message,
          child: ExcludeSemantics(
            child: Stack(
              children: <Widget>[
                ModalBarrier(
                  dismissible: false,
                  color: colors.scrim.withValues(alpha: 0.4),
                ),
                Center(
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AppLoadingIndicator(
                            width: 140,
                            semanticLabel: message,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            message,
                            style: AppTypography.bodySm,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.id,
    required this.isCurrentPlan,
    required this.isSelected,
    required this.product,
    required this.onSelected,
  });
  final String id;
  final bool isCurrentPlan;
  final bool isSelected;
  final ProductDetails? product;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy.of(context);
    final isFree = id == 'Free';
    final isPlus = id == 'Plus';
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey<String>('paywall-plan-$id'),
      color: isSelected
          ? AppPalette.subscriptionSelected
          : colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        side: isSelected
            ? BorderSide.none
            : BorderSide(
                color: colorScheme.outlineVariant,
                width: AppBorderWidth.hairline,
              ),
      ),
      child: Semantics(
        selected: isSelected,
        button: !isFree,
        child: InkWell(
          onTap: isFree ? null : onSelected,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: <Widget>[
                    Text(id, style: AppTypography.headlineMd),
                    if (isCurrentPlan) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _CurrentPlanIndicator(label: copy.currentPlanIndicator),
                    ],
                  ],
                ),
                if (!isFree) ...[
                  const SizedBox(height: AppSpacing.xs),
                  for (final String benefit in copy.planBenefits(isPlus)) ...[
                    Text('• $benefit', style: AppTypography.bodySm),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  if (isPlus) ...[
                    Text(
                      '• ${copy.plusBusinessConversationBenefit}',
                      style: AppTypography.bodySm,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (product == null)
                    Text(copy.priceUnavailable, style: AppTypography.bodySm)
                  else
                    Semantics(
                      label: copy.monthlyPrice(product!.price),
                      child: ExcludeSemantics(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              product!.price,
                              style: AppTypography.headlineMd.copyWith(
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              copy.monthlyPeriodLabel,
                              style: AppTypography.bodySm.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentPlanIndicator extends StatefulWidget {
  const _CurrentPlanIndicator({required this.label});

  final String label;

  @override
  State<_CurrentPlanIndicator> createState() => _CurrentPlanIndicatorState();
}

class _CurrentPlanIndicatorState extends State<_CurrentPlanIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.25,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  bool? _animationsDisabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == animationsDisabled) return;
    _animationsDisabled = animationsDisabled;
    if (animationsDisabled) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: ExcludeSemantics(
      child: FadeTransition(
        opacity: _opacity,
        child: Icon(
          Icons.arrow_left,
          key: const ValueKey<String>('paywall-current-plan-indicator'),
          size: 34,
        ),
      ),
    ),
  );
}
