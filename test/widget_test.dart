import 'package:flutter_test/flutter_test.dart';
import 'package:encuentrame/app/app.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AppWidget());
    expect(find.byType(AppWidget), findsOneWidget);
  });
}