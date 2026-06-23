import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CuritalkApp extends StatelessWidget {
  const CuritalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Curitalk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
