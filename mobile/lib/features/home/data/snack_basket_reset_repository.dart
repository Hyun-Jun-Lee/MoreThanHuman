import 'package:curitalk/core/network/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SnackBasketReset {
  const SnackBasketReset({required this.language, this.resetId});

  final String language;
  final String? resetId;

  factory SnackBasketReset.fromJson(Object? json) {
    if (json is! Map<String, dynamic> ||
        !json.containsKey('reset_id') ||
        !['en', 'ko'].contains(json['content_language']) ||
        (json['reset_id'] != null &&
            (json['reset_id'] is! String ||
                (json['reset_id'] as String).trim().isEmpty))) {
      throw const FormatException('Invalid snack basket reset.');
    }
    return SnackBasketReset(
      language: json['content_language'] as String,
      resetId: json['reset_id'] as String?,
    );
  }
}

abstract interface class SnackBasketResetRepository {
  Future<SnackBasketReset> read();
}

class ApiSnackBasketResetRepository implements SnackBasketResetRepository {
  const ApiSnackBasketResetRepository(this.client);
  final ApiClient client;

  @override
  Future<SnackBasketReset> read() async => (await client.get<SnackBasketReset>(
    'v2/language-snacks/basket-reset/',
    decodeData: SnackBasketReset.fromJson,
  )).data;
}

final snackBasketResetRepositoryProvider = Provider<SnackBasketResetRepository>(
  (ref) => ApiSnackBasketResetRepository(ref.watch(apiClientProvider)),
);
