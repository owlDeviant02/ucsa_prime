// Pruebas de interfaz que no requieren Firebase: el ingreso valida los campos
// antes de consultar la base, y los widgets reactivos se prueban con un
// ViewModel de prueba.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucsa_prime/app.dart';
import 'package:ucsa_prime/controllers/inventario_controller.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/ui/componentes.dart';
import 'package:ucsa_prime/ui/fondo_ucsa.dart';
import 'package:ucsa_prime/ui/tema.dart';
import 'package:ucsa_prime/views/inventario/inventario_page.dart';

class _ContadorViewModel extends ViewModel<int> {
  _ContadorViewModel() : super(0);

  void incrementar() => emitir(estado + 1);
}

Widget _envolver(Widget hijo) => MaterialApp(theme: construirTema(), home: Scaffold(body: hijo));

void main() {
  testWidgets('El ingreso exige usuario y contraseña antes de consultar Firebase', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const UcsaPrimeApp());
    await tester.pumpAndSettle();

    expect(find.text('UCSA PRIME'), findsOneWidget);
    expect(find.text('Portal de miembros'), findsOneWidget);

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresá tu usuario'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña'), findsOneWidget);
  });

  testWidgets('VistaReactiva se reconstruye con cada estado emitido (MVVM)', (tester) async {
    final vm = _ContadorViewModel();
    addTearDown(vm.dispose);
    await tester.pumpWidget(_envolver(
      VistaReactiva<int>(viewModel: vm, builder: (context, valor) => Text('Valor: $valor')),
    ));
    expect(find.text('Valor: 0'), findsOneWidget);

    vm.incrementar();
    vm.incrementar();
    await tester.pump();
    expect(find.text('Valor: 2'), findsOneWidget);
  });

  testWidgets('El fondo animado se dibuja y se libera sin errores', (tester) async {
    await tester.pumpWidget(_envolver(const FondoUcsa(animado: true, child: Text('contenido'))));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('contenido'), findsOneWidget);
    await tester.pumpWidget(_envolver(const SizedBox()));
  });

  testWidgets('El selector de stock muestra la cantidad y bloquea "−" sin stock', (tester) async {
    final vm = InventarioController();
    addTearDown(vm.dispose);
    final agotado = ComponenteInventario(
      id: 'x',
      nombre: 'Sensor de visión V5',
      categoria: 'sensores',
      cantidadDisponible: 0,
      cantidadMinima: 1,
      ubicacion: '',
      ultimaActualizacion: DateTime(2026, 11, 13),
    );
    await tester.pumpWidget(_envolver(Center(child: SelectorStock(componente: agotado, vm: vm))));

    expect(find.text('0'), findsOneWidget);
    final botones = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
    expect(botones.first.onPressed, isNull, reason: 'no se puede restar con stock 0');
    expect(botones.last.onPressed, isNotNull);
  });

  testWidgets('Los estados vacío y de error muestran su mensaje', (tester) async {
    await tester.pumpWidget(_envolver(const EstadoMensaje.error(mensaje: 'Sin conexión con Firebase.')));
    expect(find.text('No se pudieron cargar los datos'), findsOneWidget);
    expect(find.text('Sin conexión con Firebase.'), findsOneWidget);
  });
}
