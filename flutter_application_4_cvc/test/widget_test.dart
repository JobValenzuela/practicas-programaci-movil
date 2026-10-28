import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4_cvc/main.dart';

void main() {
  testWidgets('Muestra los nodos y las acciones CSV', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Importar CSV'), findsOneWidget);
    expect(find.text('001 | Sala | Temperatura'), findsOneWidget);
    expect(find.text('Ruta del archivo CSV'), findsOneWidget);
  });
}
