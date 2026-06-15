import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hscode_auditor/main.dart';

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: TariffGuardApp(),
      ),
    );

    // Verify that the app title exists
    expect(find.text('TariffGuard'), findsOneWidget);
    expect(find.text(' AI'), findsOneWidget);
  });
}
