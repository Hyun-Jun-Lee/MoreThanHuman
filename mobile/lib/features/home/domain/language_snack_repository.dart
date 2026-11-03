import 'package:curitalk/features/home/domain/language_snack.dart';

abstract interface class LanguageSnackRepository {
  Future<List<LanguageSnack>> listPublished();
}
