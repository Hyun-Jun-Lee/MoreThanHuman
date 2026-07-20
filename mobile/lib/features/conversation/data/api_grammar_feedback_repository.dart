import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/conversation/domain/grammar_feedback.dart';
import 'package:curitalk/features/conversation/domain/grammar_feedback_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiGrammarFeedbackRepository implements GrammarFeedbackRepository {
  const ApiGrammarFeedbackRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<GrammarFeedbackLookupResult> fetchFeedback(String messageId) async {
    try {
      final ApiResponse<GrammarFeedback> response = await apiClient
          .get<GrammarFeedback>(
            'grammar/message/$messageId/',
            decodeData: GrammarFeedback.fromJson,
          );
      return GrammarFeedbackFound(response.data);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return const GrammarFeedbackPending();
      }
      rethrow;
    }
  }
}

final Provider<GrammarFeedbackRepository> grammarFeedbackRepositoryProvider =
    Provider<GrammarFeedbackRepository>((Ref ref) {
      return ApiGrammarFeedbackRepository(ref.watch(apiClientProvider));
    });
