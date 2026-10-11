import 'package:flutter_test/flutter_test.dart';
import 'package:reroute_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ReRouteApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ReRouteApp());
    await tester.pump();
    expect(find.byType(ReRouteApp), findsOneWidget);
  });
}
