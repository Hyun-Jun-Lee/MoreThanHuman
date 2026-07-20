import 'package:curitalk/app/app.dart';
import 'package:curitalk/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.requiredSupabaseUrl,
    publishableKey: AppConfig.requiredSupabasePublishableKey,
  );
  runApp(const ProviderScope(child: CuritalkApp()));
}
