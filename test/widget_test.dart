import 'package:flutter_test/flutter_test.dart';
import 'package:smart_file/main.dart';

void main() {
  testWidgets('shows AuthScreen entry point and enters demo mode',
      (tester) async {
    await tester.pumpWidget(const SmartFileApp());
    await tester.pumpAndSettle();

    // Verify AuthScreen is the entry point
    expect(find.text('FileMind AI'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Explore Demo Mode (Instant)'), findsOneWidget);

    // Tap Explore Demo Mode
    await tester.tap(find.text('Explore Demo Mode (Instant)'));
    await tester.pumpAndSettle();

    // Verify MainShell is now loaded with live storage card
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Authorize Device Folder'), findsOneWidget);
    expect(find.text('AI Chat'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Navigate to AI Chat tab
    await tester.tap(find.text('AI Chat'));
    await tester.pumpAndSettle();
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.textContaining('FileMind AI'), findsWidgets);

    // Navigate to Browse tab
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Photos'), findsWidgets);
  });
}
