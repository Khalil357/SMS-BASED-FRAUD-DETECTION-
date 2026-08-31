import 'package:flutter_test/flutter_test.dart';
import 'package:secure_signal/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'show_onboarding': false});
  });

  testWidgets('shows the Secure Signal login screen', (tester) async {
    await tester.pumpWidget(const SecureSignalApp());
    // Wait for the splash screen delay and transitions
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(find.text('Welcome Back!'), findsWidgets);
    expect(find.text('Login'), findsOneWidget);
  });
}
