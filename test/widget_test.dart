import 'package:flutter_test/flutter_test.dart';
import 'package:sms_based_fraud_detection/main.dart';
import 'package:sms_based_fraud_detection/widgets/custom_button.dart';

void main() {
  testWidgets('Login page form validation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the login page title is present.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Tap the login button without filling any fields.
    await tester.tap(find.byType(CustomButton));
    await tester.pumpAndSettle();

    // Verify that validation error messages are displayed.
    expect(find.text('Please enter your phone number'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });
}
