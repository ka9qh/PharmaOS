import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaos_owner_app/main.dart';

void main() {
  testWidgets('PharmaOSOwnerApp launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PharmaOSOwnerApp());
    expect(find.byType(PharmaOSOwnerApp), findsOneWidget);
  });
}
