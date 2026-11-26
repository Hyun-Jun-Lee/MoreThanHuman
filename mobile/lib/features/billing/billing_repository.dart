import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BillingEntitlement {
  const BillingEntitlement({
    required this.plan,
    required this.status,
    this.expiresAt,
    this.source = 'free',
    this.isAdmin = false,
    this.isUnlimited = false,
    this.slotLimit,
    this.remainingTurns,
    this.trialTurns = 0,
    this.paidTurns = 0,
  });

  factory BillingEntitlement.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['plan'] is! String ||
        value['status'] is! String) {
      throw const FormatException('Billing entitlement payload is invalid.');
    }
    final rawExpiry = value['expires_at'];
    final normalized =
        rawExpiry is String &&
            !rawExpiry.endsWith('Z') &&
            !rawExpiry.contains('+')
        ? '${rawExpiry}Z'
        : rawExpiry;
    return BillingEntitlement(
      plan: value['plan'] as String,
      status: value['status'] as String,
      expiresAt: normalized is String ? DateTime.tryParse(normalized) : null,
      source:
          value['source'] as String? ??
          (value['plan'] == 'free' ? 'free' : 'apple'),
      isAdmin: value['is_admin'] as bool? ?? false,
      isUnlimited: value['unlimited'] as bool? ?? false,
      slotLimit: value['slot_limit'] as int?,
      remainingTurns: value['remaining_turns'] as int?,
      trialTurns: value['trial_turns'] as int? ?? 0,
      paidTurns: value['paid_turns'] as int? ?? 0,
    );
  }

  final String plan;
  final String status;
  final DateTime? expiresAt;
  final String source;
  final bool isAdmin;
  final bool isUnlimited;
  final int? slotLimit;
  final int? remainingTurns;
  final int trialTurns;
  final int paidTurns;
}

class BillingRepository {
  const BillingRepository(this.client);
  final ApiClient client;

  Future<BillingEntitlement> getEntitlement() async =>
      (await client.get<BillingEntitlement>(
        'billing/entitlement/',
        decodeData: BillingEntitlement.fromJson,
      )).data;

  Future<bool> verify(String signedTransaction) async =>
      (await client.post<bool>(
        'billing/apple/verify/',
        data: {'signed_transaction': signedTransaction},
        decodeData: (value) =>
            value is Map<String, dynamic> && value['terminal'] == true,
      )).data;

  Future<bool> terminalize(String signedTransaction) async =>
      (await client.post<bool>(
        'billing/apple/terminalize/',
        requiresAuth: false,
        data: {'signed_transaction': signedTransaction},
        decodeData: (value) =>
            value is Map<String, dynamic> && value['terminal'] == true,
      )).data;
}

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(apiClientProvider)),
);

final billingEntitlementProvider = FutureProvider<BillingEntitlement>((
  ref,
) async {
  final userId = ref.watch(
    authControllerProvider.select((auth) => auth.value?.user?.id),
  );
  if (userId == null) {
    return const BillingEntitlement(plan: 'free', status: 'free');
  }
  return ref.watch(billingRepositoryProvider).getEntitlement();
});
