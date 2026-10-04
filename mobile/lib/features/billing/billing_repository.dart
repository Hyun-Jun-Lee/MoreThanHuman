import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BillingEntitlement {
  const BillingEntitlement({
    required this.plan,
    required this.status,
    this.expiresAt,
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
    );
  }

  final String plan;
  final String status;
  final DateTime? expiresAt;
}

class BillingRepository {
  const BillingRepository(this.client);
  final ApiClient client;

  Future<BillingEntitlement> getEntitlement() async =>
      (await client.get<BillingEntitlement>(
        'billing/entitlement/',
        decodeData: BillingEntitlement.fromJson,
      )).data;

  Future<BillingEntitlement> verify(String signedTransaction) async =>
      (await client.post<BillingEntitlement>(
        'billing/apple/verify/',
        data: {'signed_transaction': signedTransaction},
        decodeData: BillingEntitlement.fromJson,
      )).data;
}

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(apiClientProvider)),
);

final billingEntitlementProvider = FutureProvider<BillingEntitlement>((
  ref,
) async {
  final session = ref.watch(authControllerProvider).value;
  if (session == null || !session.isAuthenticated) {
    return const BillingEntitlement(plan: 'free', status: 'free');
  }
  return ref.watch(billingRepositoryProvider).getEntitlement();
});
