import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_3/main.dart';

void main() {
  testWidgets('Muestra la vista de almacenamiento', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('JSON cifrado'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Leer'), findsOneWidget);
  });
}
