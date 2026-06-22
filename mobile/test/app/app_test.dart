import 'package:curitalk/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the Curitalk app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CuritalkApp()));

    expect(find.text('Curitalk'), findsOneWidget);
    expect(find.text('Project setup complete'), findsOneWidget);
  });
}
