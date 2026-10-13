import 'package:flutter_test/flutter_test.dart';
import 'package:phonehub/main.dart';

void main() {
  testWidgets('PhoneHub splash screen shows', (WidgetTester tester) async {
    await tester.pumpWidget(const PhoneHubApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('PhoneHub'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}