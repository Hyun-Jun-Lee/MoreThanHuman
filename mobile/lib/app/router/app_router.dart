import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const _ProjectSetupPage();
      },
    ),
  ],
);

class _ProjectSetupPage extends StatelessWidget {
  const _ProjectSetupPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Curitalk'),
            SizedBox(height: 8),
            Text('Project setup complete'),
          ],
        ),
      ),
    );
  }
}
