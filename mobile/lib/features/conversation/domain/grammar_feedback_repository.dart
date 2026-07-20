import 'package:curitalk/features/conversation/domain/grammar_feedback.dart';

sealed class GrammarFeedbackLookupResult {
  const GrammarFeedbackLookupResult();
}

class GrammarFeedbackFound extends GrammarFeedbackLookupResult {
  const GrammarFeedbackFound(this.feedback);

  final GrammarFeedback feedback;
}

class GrammarFeedbackPending extends GrammarFeedbackLookupResult {
  const GrammarFeedbackPending();
}

abstract interface class GrammarFeedbackRepository {
  Future<GrammarFeedbackLookupResult> fetchFeedback(String messageId);
}
