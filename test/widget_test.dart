import 'package:flutter_test/flutter_test.dart';
import 'package:ai_gg666/app.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const GgModifierApp());
    await tester.pumpAndSettle();

    // Verify that the main navigation is rendered.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
