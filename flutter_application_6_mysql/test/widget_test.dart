import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_6_mysql/main.dart';
import 'package:flutter_application_6_mysql/producto_api.dart';

void main() {
  testWidgets('Actualizar consulta la API y muestra los registros nuevos', (
    tester,
  ) async {
    var consultas = 0;
    final api = ProductoApi(
      client: MockClient((request) async {
        consultas++;
        return http.Response(
          jsonEncode(
            consultas == 1
                ? []
                : [
                    {
                      'id': '1',
                      'nombre': 'Producto desde SQL',
                      'precio': '25.00',
                    },
                  ],
          ),
          200,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: ProductoListScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(consultas, 2);
    expect(find.text('Producto desde SQL'), findsOneWidget);
  });

  testWidgets('Guardar cierra el formulario y muestra el producto creado', (
    tester,
  ) async {
    final productos = <Map<String, dynamic>>[];
    final api = ProductoApi(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(productos), 200);
        }
        final data = jsonDecode(request.body) as Map<String, dynamic>;
        productos.add({
          'id': '1',
          'nombre': data['nombre'],
          'precio': data['precio'],
        });
        return http.Response('{"status":"success","id":"1"}', 201);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: ProductoListScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Cuaderno nuevo');
    await tester.enterText(find.byType(TextFormField).at(1), '15.50');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Nuevo Producto'), findsNothing);
    expect(find.text('Cuaderno nuevo'), findsOneWidget);
    expect(find.text(r'$15.50'), findsOneWidget);
  });

  testWidgets('Valida el formulario y conserva los datos si la API falla', (
    tester,
  ) async {
    var guardados = 0;
    final api = ProductoApi(
      client: MockClient((request) async {
        if (request.method == 'GET') return http.Response('[]', 200);
        guardados++;
        return http.Response(
          '{"status":"error","message":"Error de prueba"}',
          500,
        );
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(MaterialApp(home: ProductoListScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('No hay productos registrados.'), findsOneWidget);
    await tester.tap(find.byTooltip('Agregar producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el nombre.'), findsOneWidget);
    expect(guardados, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'Cuaderno');
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(guardados, 1);
    expect(find.text('Error de prueba'), findsOneWidget);
    expect(find.text('Cuaderno'), findsOneWidget);
    expect(find.text('Nuevo Producto'), findsOneWidget);
  });
}
