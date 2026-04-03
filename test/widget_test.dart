import 'package:flutter_test/flutter_test.dart';

import 'package:bis_flutter/main.dart';

void main() {
  testWidgets('App renders welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BisApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to bis'), findsOneWidget);
  });
}
