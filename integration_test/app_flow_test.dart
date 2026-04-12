import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meeting_brain/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and shows initial auth screen shell', (tester) async {
    await tester.pumpWidget(const MeetingBrainApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Auth'), findsWidgets);
  });
}
