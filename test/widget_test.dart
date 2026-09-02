import 'package:flutter_test/flutter_test.dart';
import 'package:sms_based_fraud_detection/main.dart';
import 'package:sms_based_fraud_detection/widgets/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'show_onboarding': false});
  });

  testWidgets('Login page form validation smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for the splash screen delay and transitions
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // Verify that the login page title is present.
    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Phone Number or Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Tap the login button without filling any fields.
    await tester.tap(find.byType(CustomButton));
    await tester.pumpAndSettle();

    // Verify that validation error messages are displayed.
    expect(find.text('Please enter your phone number or email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });
}
