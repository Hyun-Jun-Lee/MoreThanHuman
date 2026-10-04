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
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const BillingUiState();
  }

  Future<void> loadProducts() async {
    if (!Platform.isIOS || state.isLoading) return;
    state = state.copyWith(isLoading: true);
    try {
      if (!await _store.isAvailable()) throw StateError('Store unavailable');
      final result = await _store.queryProductDetails({'Advance', 'Plus'});
      if (result.error != null || result.productDetails.length != 2) {
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
    if (!Platform.isIOS || userId == null || state.isProcessing) return;
    state = state.copyWith(isProcessing: true);
    try {
      final started = await _store.buyNonConsumable(
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

  Future<void> restore() async {
    if (!Platform.isIOS || state.isProcessing) return;
    state = state.copyWith(isProcessing: true);
    try {
      await _store.restorePurchases();
      if (ref.mounted) {
        state = state.copyWith(
          isProcessing: false,
          message: 'restore_requested',
        );
      }
    } on Object {
      if (ref.mounted) {
        state = state.copyWith(isProcessing: false, message: 'restore_failed');
      }
    }
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != 'Advance' && purchase.productID != 'Plus') {
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
    if (!_processing.add(id)) return;
    final userId = ref.read(authControllerProvider).value?.user?.id;
    bool canComplete = false;
    try {
      if (userId == null ||
          purchase.verificationData.serverVerificationData.isEmpty) {
        throw StateError('Purchase cannot be verified');
      }
      await _repository.verify(
        purchase.verificationData.serverVerificationData,
      );
      canComplete = true;
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
      canComplete =
          error.code == 'PURCHASE_ACCOUNT_CONFLICT' ||
          error.code == 'INVALID_APPLE_PURCHASE';
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
        } on Object {
          /* 다음 스트림·복원에서 재시도해요. */
        }
      }
      _processing.remove(id);
    }
  }
}

final billingControllerProvider =
    NotifierProvider<BillingController, BillingUiState>(BillingController.new);
