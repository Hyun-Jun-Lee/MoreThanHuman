import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:curitalk/features/billing/billing_controller.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
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
  final _slotsFocus = FocusNode();
  final _turnsFocus = FocusNode();
  bool _focused = false;

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
  void dispose() {
    _slotsFocus.dispose();
    _turnsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ko = AppCopy.of(context).isKorean;
    final state = ref.watch(billingControllerProvider);
    final balance = ref.watch(billingEntitlementProvider);
    final access = ref.watch(conversationAccessProvider);
    final busy =
        state.isProcessing ||
        (state.message == 'verified' && balance.isLoading);
    if (!_focused && state.products.isNotEmpty && widget.purpose != null) {
      _focused = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final slots = widget.purpose == 'buy_slots';
        final target = (slots ? _slotsKey : _turnsKey).currentContext;
        if (target != null) {
          Scrollable.ensureVisible(target);
          (slots ? _slotsFocus : _turnsFocus).requestFocus();
        }
      });
    }
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(ko ? '대화 상점' : 'Conversation store')),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(24),
              children: [
                balance.when(
                  data: (value) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ko ? '내 대화와 답변' : 'Your conversations and replies',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            value.isUnlimited
                                ? (ko ? '관리자 · 무제한' : 'Admin · Unlimited')
                                : (ko
                                      ? '보관 대화 ${access.asData?.value.usedSlots ?? '—'} / ${value.slotLimit ?? '—'}개'
                                      : 'Saved conversations ${access.asData?.value.usedSlots ?? '—'} / ${value.slotLimit ?? '—'}'),
                          ),
                          Text(
                            ko
                                ? '남은 AI 답변 ${value.isUnlimited ? '∞' : (value.remainingTurns ?? '—')}회'
                                : '${value.isUnlimited ? '∞' : (value.remainingTurns ?? '—')} AI replies remaining',
                          ),
                          Text(
                            ko
                                ? '무료 체험 ${value.trialTurns}회 · 충전 ${value.paidTurns}회'
                                : 'Trial ${value.trialTurns} · Purchased / granted ${value.paidTurns}',
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
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () =>
                          launchUrl(Uri.parse(AppConfig.subscriptionTermsUrl)),
                      child: Text(ko ? '이용약관' : 'Terms of Use'),
                    ),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(AppConfig.privacyPolicyUrlFor(isKorean: ko)),
                      ),
                      child: Text(ko ? '개인정보처리방침' : 'Privacy Policy'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  ko
                      ? '대화권 1회는 사용자 메시지 1개와 AI 텍스트 답변 1개예요. 답변 저장 전에 실패하면 반환하고, 텍스트가 저장된 뒤 음성만 실패하면 사용한 것으로 처리해요.'
                      : 'One reply credit covers one user message and one AI text reply. Failure before saving the reply returns the credit; an audio-only failure after saving text still uses it.',
                ),
                const SizedBox(height: 16),
                Text(
                  ko
                      ? '같은 tomatalk 계정으로 로그인하면 잔액을 다시 확인할 수 있어요. 계정 삭제 시 모든 추가 대화 수와 턴이 영구 소멸하며, 재가입·다른 계정에는 복원하거나 이전할 수 없어요.'
                      : 'Sign in to the same tomatalk account to access your balance. Deleting the account permanently removes all extra slots and credits. They cannot be restored after re-registration or transferred to another account.',
                ),
                const SizedBox(height: 16),
                Text(
                  ko
                      ? '자체 지원 환불은 턴 팩의 첫 답변 사용 전, 추가 대화 수 상품의 구매 후 첫 AI 텍스트 답변 저장 전까지만 검토해요. Apple 환불 요청은 Apple이 별도로 심사해요.'
                      : 'Support refund review is available before the first use of a reply pack, or before the first AI text reply saved after a slot purchase. Apple reviews its refund requests separately.',
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
                    Focus(
                      key: kind == 'slots' ? _slotsKey : _turnsKey,
                      focusNode: kind == 'slots' ? _slotsFocus : _turnsFocus,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),
                          Text(
                            kind == 'slots'
                                ? (ko ? '추가 대화 수' : 'Extra conversation slots')
                                : (ko ? 'AI 답변 충전' : 'AI reply credits'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          for (final product in state.products.where(
                            (p) => p.id.contains('.$kind.'),
                          ))
                            Card(
                              child: ListTile(
                                title: Text(
                                  kind == 'slots'
                                      ? (ko
                                            ? '대화 +${product.id.split('.').last}개'
                                            : '+${product.id.split('.').last} conversations')
                                      : (ko
                                            ? '답변 ${product.id.split('.').last}회'
                                            : '${product.id.split('.').last} replies'),
                                ),
                                subtitle: Text(product.price),
                                trailing: FilledButton(
                                  onPressed:
                                      busy ||
                                          balance.asData?.value == null ||
                                          balance.asData?.value.isUnlimited ==
                                              true
                                      ? null
                                      : () => ref
                                            .read(
                                              billingControllerProvider
                                                  .notifier,
                                            )
                                            .purchase(product),
                                  child: Text(ko ? '구매' : 'Buy'),
                                ),
                              ),
                            ),
                        ],
                      ),
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
