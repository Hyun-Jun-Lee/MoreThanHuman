import 'dart:async';

import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/data/conversation_access_repository.dart';
import 'package:curitalk/features/home/data/api_home_repository.dart';
import 'package:curitalk/features/home/domain/conversation_summary.dart';
import 'package:curitalk/features/home/domain/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecentConversationsController
    extends AsyncNotifier<List<ConversationSummary>> {
  @override
  Future<List<ConversationSummary>> build() async {
    final AuthSession? session = ref.watch(authControllerProvider).value;
    if (session == null || !session.isAuthenticated) {
      return const <ConversationSummary>[];
    }
    await _reconcileAccessBestEffort();
    final HomeRepository repository = ref.watch(homeRepositoryProvider);
    try {
      return await repository.listRecentConversations();
    } finally {
      scheduleMicrotask(() {
        if (ref.mounted) {
          _setRefreshing(false);
        }
      });
    }
  }

  Future<void> reload() async {
    _setRefreshing(true);
    state = const AsyncLoading<List<ConversationSummary>>();
    try {
      await _reconcileAccessBestEffort(refresh: true);
      state = await AsyncValue.guard(
        ref.read(homeRepositoryProvider).listRecentConversations,
      );
    } finally {
      _setRefreshing(false);
    }
  }

  Future<void> refreshAfterMutation(Future<void> Function() mutation) async {
    final List<ConversationSummary>? previous = state.value;
    _setRefreshing(true);
    state = const AsyncLoading<List<ConversationSummary>>();
    try {
      await mutation();
      await _reconcileAccessBestEffort(refresh: true);
      final List<ConversationSummary> conversations = await ref
          .read(homeRepositoryProvider)
          .listRecentConversations();
      state = AsyncData<List<ConversationSummary>>(conversations);
    } on Object catch (error, stackTrace) {
      state = previous == null
          ? AsyncError<List<ConversationSummary>>(error, stackTrace)
          : AsyncData<List<ConversationSummary>>(previous);
      rethrow;
    } finally {
      _setRefreshing(false);
    }
  }

  Future<void> _reconcileAccessBestEffort({bool refresh = false}) async {
    if (refresh) {
      ref.invalidate(conversationAccessProvider);
    }
    try {
      await ref.read(conversationAccessProvider.future);
    } on Object {
      return;
    }
  }

  void _setRefreshing(bool isRefreshing) {
    ref
        .read(recentConversationsRefreshingProvider.notifier)
        .setRefreshing(isRefreshing);
  }
}

class RecentConversationsRefreshingController extends Notifier<bool> {
  @override
  bool build() => false;

  void setRefreshing(bool isRefreshing) {
    state = isRefreshing;
  }
}

final NotifierProvider<RecentConversationsRefreshingController, bool>
recentConversationsRefreshingProvider =
    NotifierProvider<RecentConversationsRefreshingController, bool>(
      RecentConversationsRefreshingController.new,
    );

final AsyncNotifierProvider<
  RecentConversationsController,
  List<ConversationSummary>
>
recentConversationsControllerProvider =
    AsyncNotifierProvider<
      RecentConversationsController,
      List<ConversationSummary>
    >(RecentConversationsController.new);
