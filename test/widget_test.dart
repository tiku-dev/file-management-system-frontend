import 'package:flutter_test/flutter_test.dart';
import 'package:smart_file/main.dart';

void main() {
  testWidgets('shows the Smart File shell', (tester) async {
    await tester.pumpWidget(const SmartFileApp());

    expect(find.text('Smart File'), findsOneWidget);
    expect(find.text('Choose a folder to begin'), findsOneWidget);
  });
}
