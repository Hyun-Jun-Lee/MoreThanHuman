import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('turns 404-style pending into completed feedback', () async {
    final _FakeGrammarFeedbackRepository repository =
        _FakeGrammarFeedbackRepository(pendingResponses: 1);
    final ProviderContainer container = _container(repository);
    addTearDown(container.dispose);

    expect(
      container
          .read(grammarFeedbackPollingControllerProvider('message-id'))
          .status,
      GrammarFeedbackPollingStatus.pending,
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final GrammarFeedbackPollingState state = container.read(
      grammarFeedbackPollingControllerProvider('message-id'),
    );
    expect(state.status, GrammarFeedbackPollingStatus.completed);
    expect(state.feedback?.correctedText, 'I was surprised.');
  });

  test('times out when feedback remains pending', () async {
    final ProviderContainer container = _container(
      _FakeGrammarFeedbackRepository(pendingResponses: 99),
    );
    addTearDown(container.dispose);

    container.read(grammarFeedbackPollingControllerProvider('message-id'));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      container
          .read(grammarFeedbackPollingControllerProvider('message-id'))
          .status,
      GrammarFeedbackPollingStatus.timeout,
    );
  });
}

ProviderContainer _container(GrammarFeedbackRepository repository) {
  return ProviderContainer(
    overrides: [
      grammarFeedbackRepositoryProvider.overrideWithValue(repository),
      grammarFeedbackPollingConfigProvider.overrideWithValue(
        const GrammarFeedbackPollingConfig(
          interval: Duration(milliseconds: 10),
          timeout: Duration(milliseconds: 35),
        ),
      ),
    ],
  );
}

class _FakeGrammarFeedbackRepository implements GrammarFeedbackRepository {
  _FakeGrammarFeedbackRepository({required this.pendingResponses});

  final int pendingResponses;
  int calls = 0;

  @override
  Future<GrammarFeedbackLookupResult> fetchFeedback(String messageId) async {
    calls++;
    if (calls <= pendingResponses) {
      return const GrammarFeedbackPending();
    }
    return GrammarFeedbackFound(
      GrammarFeedback(
        id: 'feedback-id',
        messageId: messageId,
        originalText: 'I was surprise.',
        correctedText: 'I was surprised.',
        hasErrors: true,
        errors: const <GrammarError>[
          GrammarError(
            original: 'surprise',
            corrected: 'surprised',
            explanation: 'Use the past participle after was.',
          ),
        ],
        createdAt: DateTime.utc(2026, 7, 2),
      ),
    );
  }
}
