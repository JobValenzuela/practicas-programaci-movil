import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer_app/main.dart';

void main() {
  testWidgets('Namer App displays a random word pair', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('A random idea:'), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(2));
  });
}
