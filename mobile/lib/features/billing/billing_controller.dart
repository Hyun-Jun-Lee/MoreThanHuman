import 'dart:async';
import 'dart:io';

import 'package:curitalk/core/network/api_exception.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/billing/billing_repository.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
import 'package:curitalk/features/history/application/conversation_history_controller.dart';
import 'package:curitalk/features/home/application/recent_conversations_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class BillingUiState {
  const BillingUiState({
    this.products = const [],
    this.isLoading = false,
    this.isProcessing = false,
    this.message,
  });
  final List<ProductDetails> products;
  final bool isLoading;
  final bool isProcessing;
  final String? message;

  BillingUiState copyWith({
    List<ProductDetails>? products,
    bool? isLoading,
    bool? isProcessing,
    String? message,
  }) => BillingUiState(
    products: products ?? this.products,
    isLoading: isLoading ?? this.isLoading,
    isProcessing: isProcessing ?? this.isProcessing,
    message: message,
  );
}

class BillingController extends Notifier<BillingUiState> {
  late InAppPurchase _store;
  late BillingRepository _repository;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Set<String> _processing = {};
  final Map<String, PurchaseDetails> _pendingVerification = {};
  static const productIds = {
    'com.morethanhuman.curitalk.slots.plus.1',
    'com.morethanhuman.curitalk.slots.plus.3',
    'com.morethanhuman.curitalk.turns.5',
    'com.morethanhuman.curitalk.turns.10',
    'com.morethanhuman.curitalk.turns.20',
  };

  @override
  BillingUiState build() {
    _store = InAppPurchase.instance;
    _repository = ref.read(billingRepositoryProvider);
    if (Platform.isIOS) {
      _subscription = _store.purchaseStream.listen(
        _handlePurchases,
        onError: (Object _) {
          if (ref.mounted) {
            state = state.copyWith(isProcessing: false, message: 'store_error');
          }
        },
      );
    }
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.value?.user?.id != next.value?.user?.id ||
          previous?.value?.isGuest != next.value?.isGuest) {
        Future<void>.microtask(retryPendingPurchases);
      }
    });
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const BillingUiState();
  }

  Future<void> retryPendingPurchases() async {
    for (final purchase in _pendingVerification.values.toList()) {
      await _verifyPurchase(purchase);
    }
  }

  Future<void> loadProducts() async {
    if (!Platform.isIOS || state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      if (!await _store.isAvailable()) throw StateError('Store unavailable');
      final result = await _store.queryProductDetails(productIds);
      if (result.error != null ||
          result.productDetails.length != productIds.length) {
        throw StateError('Products unavailable');
      }
      if (ref.mounted) {
        state = state.copyWith(
          products: result.productDetails,
          isLoading: false,
        );
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          message: 'products_unavailable',
        );
      }
    }
  }

  Future<void> purchase(ProductDetails product) async {
    final userId = ref.read(authControllerProvider).value?.user?.id;
    if (!Platform.isIOS ||
        userId == null ||
        ref.read(authControllerProvider).value?.isMember != true ||
        state.isProcessing) {
      return;
    }
    state = state.copyWith(isProcessing: true);
    try {
      final started = await _store.buyConsumable(
        purchaseParam: Sk2PurchaseParam(
          productDetails: product,
          applicationUserName: userId,
        ),
      );
      if (!started && ref.mounted) {
        state = state.copyWith(isProcessing: false, message: 'purchase_failed');
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(isProcessing: false, message: 'purchase_failed');
      }
    }
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (!productIds.contains(purchase.productID)) {
        continue;
      }
      if (purchase.status == PurchaseStatus.pending) {
        state = state.copyWith(isProcessing: true);
      } else if (purchase.status == PurchaseStatus.error) {
        state = state.copyWith(isProcessing: false, message: 'purchase_failed');
      } else if (purchase.status == PurchaseStatus.canceled) {
        state = state.copyWith(
          isProcessing: false,
          message: 'purchase_canceled',
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        unawaited(_verifyPurchase(purchase));
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final id =
        purchase.purchaseID ?? purchase.verificationData.serverVerificationData;
    _pendingVerification[id] = purchase;
    if (!_processing.add(id)) return;
    final userId = ref.read(authControllerProvider).value?.user?.id;
    bool canComplete = false;
    try {
      final signed = purchase.verificationData.serverVerificationData;
      if (signed.isEmpty) throw StateError('Purchase cannot be verified');
      if (ref.mounted) state = state.copyWith(isProcessing: true);
      canComplete = ref.read(authControllerProvider).value?.isMember != true
          ? await _repository.terminalize(signed)
          : await _repository.verify(signed);
      if (!canComplete) throw StateError('Delivery not terminal');
      if (ref.mounted &&
          ref.read(authControllerProvider).value?.user?.id == userId) {
        ref.invalidate(billingEntitlementProvider);
        ref.invalidate(conversationAccessProvider);
        ref.invalidate(conversationTurnAccessProvider);
        ref.invalidate(conversationHistoryControllerProvider);
        ref.invalidate(recentConversationsControllerProvider);
        state = state.copyWith(isProcessing: false, message: 'verified');
      }
    } on ApiException catch (error) {
      canComplete = false;
      if (ref.mounted) {
        state = state.copyWith(
          isProcessing: false,
          message: error.code == 'PURCHASE_ACCOUNT_CONFLICT'
              ? 'account_conflict'
              : 'verification_failed',
        );
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(
          isProcessing: false,
          message: 'verification_failed',
        );
      }
    } finally {
      if (canComplete && purchase.pendingCompletePurchase) {
        try {
          await _store.completePurchase(purchase);
          _pendingVerification.remove(id);
        } on Object {
          /* 다음 구매 스트림에서 재시도해요. */
        }
      }
      if (canComplete && !purchase.pendingCompletePurchase) {
        _pendingVerification.remove(id);
      }
      _processing.remove(id);
      if (ref.mounted && _processing.isEmpty) {
        state = state.copyWith(isProcessing: false, message: state.message);
      }
    }
  }
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingUiState>(BillingController.new);
