import 'package:flutter_test/flutter_test.dart';
import 'package:secure_signal/main.dart';

void main() {
  testWidgets('shows the Secure Signal login screen', (tester) async {
    await tester.pumpWidget(const SecureSignalApp());
    expect(find.text('Secure Signal'), findsWidgets);
    expect(find.text('Login  →'), findsOneWidget);
  });
}
