import 'package:flutter_test/flutter_test.dart';
import 'package:reroute_app/main.dart';

void main() {
  testWidgets('ReRouteApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ReRouteApp());
    expect(find.byType(ReRouteApp), findsOneWidget);
  });
}
