import 'package:flutter_test/flutter_test.dart';
import 'package:ucsa_prime/models/actividad.dart';
import 'package:ucsa_prime/models/bitacora.dart';
import 'package:ucsa_prime/models/checklist.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/models/json.dart';
import 'package:ucsa_prime/models/tarea.dart';
import 'package:ucsa_prime/models/usuario.dart';
import 'package:ucsa_prime/services/datos_demo.dart';

void main() {
  final fecha = DateTime.utc(2025, 1, 15, 14, 30);

  group('ComponenteInventario', () {
    const json = {
      'id': 'motor-v5-001',
      'nombre': 'Motor VEX V5 Smart',
      'categoria': 'motores',
      'cantidadDisponible': 12,
      'cantidadMinima': 8,
      'ubicacion': 'Caja A-3',
      'ultimaActualizacion': '2025-01-15T14:30:00.000Z',
    };

    test('toJson/fromJson conserva todos los campos (estructura de la tesis)', () {
      final c = ComponenteInventario.fromJson(Map<String, dynamic>.from(json));
      expect(c.nombre, 'Motor VEX V5 Smart');
      expect(c.cantidadDisponible, 12);
      expect(c.ultimaActualizacion.toUtc(), fecha);
      expect(c.toJson(), json);
    });

    test('fromJson tolera números como double o texto y campos faltantes', () {
      final c = ComponenteInventario.fromJson({'nombre': 'Cilindro', 'cantidadDisponible': 3.0, 'cantidadMinima': '2'});
      expect(c.cantidadDisponible, 3);
      expect(c.cantidadMinima, 2);
      expect(c.categoria, 'otros');
      expect(c.ubicacion, '');
    });

    test('listaDesdeNodo recorre inventario/{categoria}/{id} y ordena por nombre', () {
      final nodo = <Object?, Object?>{
        'sensores': <Object?, Object?>{
          'imu': <Object?, Object?>{'nombre': 'Sensor inercial', 'cantidadDisponible': 2, 'cantidadMinima': 1},
        },
        'motores': <Object?, Object?>{
          'm1': <Object?, Object?>{'nombre': 'Motor V5', 'categoria': 'Actuadores', 'cantidadDisponible': 3},
          'basura': 'no es un mapa',
        },
      };
      final lista = ComponenteInventario.listaDesdeNodo(nodo);
      expect(lista.map((c) => c.id), ['m1', 'imu']);
      // La categoría la define la clave del nodo, no el campo guardado.
      expect(lista.first.categoria, 'motores');
      expect(ComponenteInventario.listaDesdeNodo(null), isEmpty);
    });

    test('stock bajo cuando la cantidad llega al mínimo', () {
      final base = ComponenteInventario.fromJson(Map<String, dynamic>.from(json));
      expect(base.stockBajo, isFalse);
      expect(base.copyWith(cantidadDisponible: 8).stockBajo, isTrue);
      expect(base.copyWith(cantidadDisponible: 0).agotado, isTrue);
    });
  });

  group('Transacción de stock (lectura-comparación-escritura)', () {
    final actual = <Object?, Object?>{'nombre': 'Motor V5', 'cantidadDisponible': 3, 'cantidadMinima': 4};

    test('aplica el delta y actualiza metadatos', () {
      final r = ComponenteInventario.calcularAjuste(actual, delta: -2, fecha: fecha, usuario: 'Ana');
      expect(r, isA<AjusteAplicado>());
      final aplicado = r as AjusteAplicado;
      expect(aplicado.cantidadAnterior, 3);
      expect(aplicado.cantidadNueva, 1);
      expect(aplicado.datos['cantidadDisponible'], 1);
      expect(aplicado.datos['actualizadoPor'], 'Ana');
      expect(aplicado.datos['nombre'], 'Motor V5');
    });

    test('aborta si el stock quedaría negativo', () {
      final r = ComponenteInventario.calcularAjuste(actual, delta: -4, fecha: fecha, usuario: 'Ana');
      expect(r, isA<AjusteInsuficiente>());
      expect((r as AjusteInsuficiente).disponible, 3);
    });

    test('sin datos válidos no escribe nada', () {
      expect(ComponenteInventario.calcularAjuste(null, delta: 1, fecha: fecha, usuario: 'Ana'), isA<AjusteSinDatos>());
      expect(ComponenteInventario.calcularAjuste(5, delta: 1, fecha: fecha, usuario: 'Ana'), isA<AjusteSinDatos>());
    });
  });

  test('FiltroInventario busca sin distinguir acentos ni mayúsculas', () {
    final c = ComponenteInventario.fromJson({
      'nombre': 'Depósito neumático 116 mL',
      'categoria': 'neumaticos',
      'cantidadDisponible': 1,
      'cantidadMinima': 1,
      'ubicacion': 'Caja N-1',
    });
    expect(const FiltroInventario(texto: 'DEPOSITO').coincide(c), isTrue);
    expect(const FiltroInventario(texto: 'neumáticos').coincide(c), isTrue);
    expect(const FiltroInventario(texto: 'caja n').coincide(c), isTrue);
    expect(const FiltroInventario(categoria: 'motores').coincide(c), isFalse);
    expect(const FiltroInventario(soloStockBajo: true).coincide(c), isTrue);
    expect(normalizar('Árbol Ñandú'), 'arbol nandu');
  });

  group('Tarea', () {
    final tarea = Tarea(
      id: 't1',
      titulo: 'Calibrar odometría',
      descripcion: 'Ajustar constantes de tracking wheels',
      asignadoA: 'Juan Pérez',
      prioridad: PrioridadTarea.alta,
      estado: EstadoTarea.enProgreso,
      fechaCreacion: DateTime.utc(2025, 1, 10, 9),
      fechaVencimiento: DateTime.utc(2025, 1, 12, 18),
      creadoPor: 'Ana',
    );

    test('toJson/fromJson ida y vuelta', () {
      final copia = Tarea.fromJson('t1', tarea.toJson());
      expect(copia.toJson(), tarea.toJson());
      expect(tarea.toJson()['estado'], 'en_progreso');
      expect(tarea.toJson()['prioridad'], 'alta');
    });

    test('estados tolerantes a variantes escritas a mano', () {
      expect(EstadoTarea.desdeClave('en progreso'), EstadoTarea.enProgreso);
      expect(EstadoTarea.desdeClave('Completado'), EstadoTarea.completada);
      expect(EstadoTarea.desdeClave(null), EstadoTarea.pendiente);
      expect(PrioridadTarea.desdeClave('ALTA'), PrioridadTarea.alta);
      expect(EstadoTarea.completada.siguiente, EstadoTarea.pendiente);
    });

    test('vencimiento y cambio de estado', () {
      final ahora = DateTime(2025, 1, 13, 10);
      expect(tarea.estaVencida(ahora), isTrue);
      final hecha = tarea.conEstado(EstadoTarea.completada, ahora: ahora);
      expect(hecha.estaVencida(ahora), isFalse);
      expect(hecha.fechaCompletada, ahora);
      expect(hecha.conEstado(EstadoTarea.pendiente).fechaCompletada, isNull);
    });

    test('orden del tablero: prioridad y luego vencimiento', () {
      final base = DateTime(2025, 1, 1);
      Tarea t(String id, PrioridadTarea p, DateTime? vence) =>
          Tarea(id: id, titulo: id, prioridad: p, fechaCreacion: base, fechaVencimiento: vence);
      final lista = [
        t('baja', PrioridadTarea.baja, null),
        t('alta-sin-fecha', PrioridadTarea.alta, null),
        t('alta-pronto', PrioridadTarea.alta, DateTime(2025, 1, 2)),
        t('media', PrioridadTarea.media, DateTime(2025, 1, 3)),
      ]..sort(Tarea.compararParaTablero);
      expect(lista.map((x) => x.id), ['alta-pronto', 'alta-sin-fecha', 'media', 'baja']);
    });
  });

  group('EntradaBitacora', () {
    test('toJson/fromJson con marca de IA y apunte original', () {
      final entrada = EntradaBitacora(
        id: 'b1',
        fecha: fecha,
        autor: 'Ana',
        tipo: TipoBitacora.prueba,
        contenido: 'BITÁCORA TÉCNICA - PRUEBA\n\nACTIVIDAD REALIZADA: …',
        generadaPorIA: true,
        apunteOriginal: 'hoy probamos el autonomo',
      );
      final copia = EntradaBitacora.fromJson('b1', entrada.toJson());
      expect(copia.generadaPorIA, isTrue);
      expect(copia.apunteOriginal, 'hoy probamos el autonomo');
      expect(copia.tipo, TipoBitacora.prueba);
      expect(copia.titulo, 'BITÁCORA TÉCNICA - PRUEBA');
    });

    test('la vista previa muestra lo que sigue al título, sin repetirlo', () {
      EntradaBitacora con(String contenido) =>
          EntradaBitacora(id: 'v', fecha: fecha, autor: 'Ana', tipo: TipoBitacora.otro, contenido: contenido);

      final varias = con('\n  Prueba del autónomo\n\nEl robot se desvió 5 cm.\nSe recalibró la IMU.\n');
      expect(varias.titulo, 'Prueba del autónomo');
      expect(varias.vistaPrevia, 'El robot se desvió 5 cm. Se recalibró la IMU.');

      // Una sola línea corta: no hay nada más que mostrar.
      expect(con('Se cambió la cadena').vistaPrevia, isEmpty);
      expect(con('').vistaPrevia, isEmpty);

      // Primera línea larga: el título se corta y la vista previa continúa desde el corte.
      final larga = con('${'a' * 87}bcdef ghi\nSegunda línea');
      expect(larga.titulo, '${'a' * 87}…');
      expect(larga.vistaPrevia, '…bcdef ghi Segunda línea');
      expect(larga.vistaPrevia, isNot(contains(larga.titulo.substring(0, 20))));
    });

    test('importa las claves de la versión 2.0 e ignora los usuarios de la raíz', () {
      final antigua = EntradaBitacora.desdeRegistroAntiguo('5-8-2025_9-7-3_Juan Pérez', 'Se cambió la cadena');
      expect(antigua, isNotNull);
      expect(antigua!.id, 'legacy-5-8-2025_9-7-3_Juan Pérez');
      expect(antigua.fecha, DateTime(2025, 8, 5, 9, 7, 3));
      expect(antigua.autor, 'Juan Pérez');
      expect(antigua.importada, isTrue);
      // Un nodo de usuario (mapa con name/password) no es una bitácora.
      expect(EntradaBitacora.desdeRegistroAntiguo('1234567', {'name': 'X', 'password': 'y'}), isNull);
      expect(EntradaBitacora.desdeRegistroAntiguo('ucsa-prime-robotics', 'texto'), isNull);
    });
  });

  group('RegistroChecklist', () {
    test('lee los ítems como lista o como mapa (formatos de Firebase)', () {
      final registro = RegistroChecklist(
        id: 'c1',
        robot: 'Jordan',
        fecha: fecha,
        usuario: 'Ana',
        items: [
          ItemVerificado(nombre: 'Batería', ok: true, hora: fecha),
          const ItemVerificado(nombre: 'Carga Aire', ok: false),
        ],
      );
      final json = registro.toJson();
      expect(json['completados'], 1);
      final comoLista = RegistroChecklist.fromJson('c1', json);
      expect(comoLista.items.map((i) => i.nombre), ['Batería', 'Carga Aire']);
      expect(comoLista.pendientes, ['Carga Aire']);

      final items = json['items'] as List;
      final comoMapa = RegistroChecklist.fromJson('c1', {...json, 'items': {'0': items[0], '1': items[1]}});
      expect(comoMapa.completados, 1);
      expect(comoMapa.completo, isFalse);
    });

    test('las plantillas conservan los ítems del equipo', () {
      final jordan = plantillasChecklist.first;
      expect(jordan.robot, 'Jordan');
      expect(jordan.items, hasLength(10));
      expect(jordan.items, containsAll(['Batería', 'Carga Aire', 'Sensor Inercial', 'Tragadera', 'Brazo']));
    });
  });

  group('Datos de demostración', () {
    final ahora = DateTime(2026, 11, 13, 10);

    test('10 componentes VEX con ids únicos y 2 en stock bajo', () {
      final componentes = DatosDemo.componentes('Ana', ahora);
      expect(componentes, hasLength(10));
      expect(componentes.map((c) => c.id).toSet(), hasLength(10));
      expect(componentes.every((c) => c.id.startsWith('demo-')), isTrue);
      expect(componentes.where((c) => c.stockBajo).map((c) => c.id), ['demo-motor-v5', 'demo-encoder-optico']);
    });

    test('la escritura multiruta usa la estructura inventario/{categoria}/{id}', () {
      final cambios = DatosDemo.cambiosCarga(usuario: 'Ana', ahora: ahora);
      expect(cambios.keys, contains('inventario/motores/demo-motor-v5'));
      expect(cambios.keys, contains('tareas/demo-tarea-odometria'));
      expect(cambios.keys, contains('bitacoras/demo-bitacora-autonomo'));
      final borrado = DatosDemo.cambiosBorrado();
      expect(borrado.values.every((v) => v == null), isTrue);
      expect(borrado.keys, containsAll(cambios.keys));
    });
  });

  test('historial de movimientos, actividad y perfiles se ordenan y toleran basura', () {
    final movimientos = MovimientoInventario.listaDesdeNodo(<Object?, Object?>{
      '-a': <Object?, Object?>{'delta': -1, 'cantidadResultante': 2, 'usuario': 'Ana', 'fecha': '2026-11-13T10:00:00Z'},
      '-b': <Object?, Object?>{'delta': 3, 'cantidadResultante': 5, 'usuario': 'Luis', 'fecha': '2026-11-13T12:00:00Z'},
      '-c': 'dato inválido',
    });
    expect(movimientos.map((m) => m.delta), [3, -1], reason: 'del más reciente al más antiguo');

    final actividad = Actividad.listaDesdeNodo(<Object?, Object?>{
      '-x': <Object?, Object?>{'tipo': 'tarea', 'descripcion': 'A', 'usuario': 'Ana', 'fecha': '2026-11-12T10:00:00Z'},
      '-y': <Object?, Object?>{'tipo': 'desconocido', 'descripcion': 'B', 'fecha': '2026-11-13T10:00:00Z'},
    });
    expect(actividad.first.descripcion, 'B');
    expect(actividad.first.tipo, TipoActividad.sistema);
    expect(actividad.first.usuario, 'Desconocido');

    final usuarios = Usuario.listaDesdeNodo(<Object?, Object?>{
      '222': <Object?, Object?>{'nombre': 'Zoe'},
      '111': <Object?, Object?>{'name': 'Ángel'},
    });
    expect(usuarios.map((u) => u.nombre), ['Ángel', 'Zoe']);
  });

  test('iniciales del avatar', () {
    expect(inicialesDe('Juan Pérez'), 'JP');
    expect(inicialesDe('  ana  '), 'A');
    expect(inicialesDe(''), '?');
    expect(const Usuario(id: '1', nombre: 'María José Gómez').iniciales, 'MG');
  });
}
