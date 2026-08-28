import 'dart:async';

import 'package:curitalk/features/conversation/data/api_grammar_feedback_repository.dart';
import 'package:curitalk/features/conversation/domain/grammar_feedback.dart';
import 'package:curitalk/features/conversation/domain/grammar_feedback_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum GrammarFeedbackPollingStatus { pending, completed, timeout, error }

enum GrammarFeedbackFailureReason { requestFailed }

class GrammarFeedbackPollingState {
  const GrammarFeedbackPollingState({
    required this.status,
    this.feedback,
    this.failureReason,
  });

  const GrammarFeedbackPollingState.pending()
    : status = GrammarFeedbackPollingStatus.pending,
      feedback = null,
      failureReason = null;

  final GrammarFeedbackPollingStatus status;
  final GrammarFeedback? feedback;
  final GrammarFeedbackFailureReason? failureReason;
}

class GrammarFeedbackPollingConfig {
  const GrammarFeedbackPollingConfig({
    this.interval = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 30),
  });

  final Duration interval;
  final Duration timeout;
}

final Provider<GrammarFeedbackPollingConfig>
grammarFeedbackPollingConfigProvider = Provider<GrammarFeedbackPollingConfig>((
  Ref ref,
) {
  return const GrammarFeedbackPollingConfig();
});

class GrammarFeedbackPollingController
    extends Notifier<GrammarFeedbackPollingState> {
  GrammarFeedbackPollingController(this.messageId);

  final String messageId;
  bool _disposed = false;

  @override
  GrammarFeedbackPollingState build() {
    ref.onDispose(() => _disposed = true);
    unawaited(_pollUntilComplete());
    return const GrammarFeedbackPollingState.pending();
  }

  Future<void> _pollUntilComplete() async {
    final GrammarFeedbackPollingConfig config = ref.read(
      grammarFeedbackPollingConfigProvider,
    );
    final DateTime deadline = DateTime.now().add(config.timeout);

    while (!_disposed) {
      try {
        final GrammarFeedbackLookupResult result = await ref
            .read(grammarFeedbackRepositoryProvider)
            .fetchFeedback(messageId);
        if (_disposed) {
          return;
        }
        if (result is GrammarFeedbackFound) {
          state = GrammarFeedbackPollingState(
            status: GrammarFeedbackPollingStatus.completed,
            feedback: result.feedback,
          );
          return;
        }
      } on Object catch (_) {
        if (!_disposed) {
          state = const GrammarFeedbackPollingState(
            status: GrammarFeedbackPollingStatus.error,
            failureReason: GrammarFeedbackFailureReason.requestFailed,
          );
        }
        return;
      }

      if (DateTime.now().isAfter(deadline)) {
        state = const GrammarFeedbackPollingState(
          status: GrammarFeedbackPollingStatus.timeout,
        );
        return;
      }
      await Future<void>.delayed(config.interval);
    }
  }
}

final grammarFeedbackPollingControllerProvider =
    NotifierProvider.family<
      GrammarFeedbackPollingController,
      GrammarFeedbackPollingState,
      String
    >(GrammarFeedbackPollingController.new);
