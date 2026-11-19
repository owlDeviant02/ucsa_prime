/// Datos de demostración de la aplicación (capa de servicios).
///
/// Genera las escrituras multiruta que `DashboardController` usa para cargar o
/// quitar, desde el menú de la pantalla de inicio, un conjunto de componentes,
/// tareas y una entrada de bitácora de ejemplo en los nodos `inventario`,
/// `tareas` y `bitacoras` de Realtime Database.
library;

import 'package:ucsa_prime/models/bitacora.dart';
import 'package:ucsa_prime/models/componente_inventario.dart';
import 'package:ucsa_prime/models/tarea.dart';

/// Datos de demostración para la defensa: componentes VEX reales, tareas del
/// proyecto y el ejemplo de bitácora del apartado IV.6.3.4. Solo se escriben
/// cuando el usuario lo pide desde el menú del inicio. Las claves son fijas
/// (prefijo `demo-`), así que cargarlos dos veces no duplica nada y se pueden
/// quitar sin tocar los datos reales del equipo.
abstract final class DatosDemo {
  /// Componentes VEX de ejemplo, algunos por debajo del mínimo para mostrar la
  /// alerta de stock bajo.
  static List<ComponenteInventario> componentes(String usuario, DateTime ahora) {
    ComponenteInventario c(String categoria, String id, String nombre, int disponible, int minimo, String ubicacion) =>
        ComponenteInventario(
          id: id,
          nombre: nombre,
          categoria: categoria,
          cantidadDisponible: disponible,
          cantidadMinima: minimo,
          ubicacion: ubicacion,
          ultimaActualizacion: ahora,
          actualizadoPor: usuario,
        );
    return [
      c('motores', 'demo-motor-v5', 'Motor V5 11 W', 3, 4, 'Caja A-3'),
      c('motores', 'demo-cartucho-600', 'Cartucho de engranajes 600 rpm (azul)', 6, 2, 'Caja A-3'),
      c('sensores', 'demo-sensor-inercial', 'Sensor inercial V5 (IMU)', 2, 1, 'Gabinete S-1'),
      c('sensores', 'demo-sensor-vision', 'Sensor de visión V5', 2, 1, 'Gabinete S-1'),
      c('sensores', 'demo-rueda-seguimiento', 'Rueda de seguimiento 2.75"', 3, 2, 'Caja B-2'),
      c('sensores', 'demo-encoder-optico', 'Encoder óptico de eje (3 hilos, 360 CPR)', 2, 2, 'Gabinete S-2'),
      c('neumaticos', 'demo-cilindro', 'Cilindro neumático de doble efecto', 6, 4, 'Caja N-1'),
      c('neumaticos', 'demo-deposito-116', 'Depósito neumático 116 mL', 2, 1, 'Caja N-1'),
      c('electronica', 'demo-bateria-v5', 'Batería V5 (1100 mAh)', 4, 3, 'Estación de carga'),
      c('estructurales', 'demo-rueda-omni', 'Rueda omnidireccional 4"', 8, 6, 'Caja C-1'),
    ];
  }

  /// Tareas de ejemplo en los tres estados, con vencimientos relativos a [ahora]
  /// (incluida una vencida), asignadas a [usuario].
  static List<Tarea> tareas(String usuario, DateTime ahora) {
    Tarea t(String id, String titulo, String descripcion, PrioridadTarea prioridad, EstadoTarea estado,
            int? venceEnDias) =>
        Tarea(
          id: id,
          titulo: titulo,
          descripcion: descripcion,
          asignadoA: usuario,
          prioridad: prioridad,
          estado: estado,
          fechaCreacion: ahora.subtract(const Duration(days: 2)),
          fechaVencimiento:
              venceEnDias == null ? null : DateTime(ahora.year, ahora.month, ahora.day + venceEnDias, 18),
          creadoPor: usuario,
          fechaCompletada: estado == EstadoTarea.completada ? ahora.subtract(const Duration(hours: 5)) : null,
        );
    return [
      t('demo-tarea-odometria', 'Calibrar odometría',
          'Ajustar las constantes de las ruedas de seguimiento y verificar un error menor a 2 cm en 3 m.',
          PrioridadTarea.alta, EstadoTarea.enProgreso, 1),
      t('demo-tarea-neumatica', 'Revisar fugas del sistema neumático',
          'Inspeccionar racores y mangueras; confirmar 100 psi en el depósito antes del torneo.',
          PrioridadTarea.alta, EstadoTarea.pendiente, 0),
      t('demo-tarea-vision', 'Recalibrar firmas del sensor de visión',
          'Actualizar las firmas de color de los aros rojo y azul con la iluminación del gimnasio.',
          PrioridadTarea.media, EstadoTarea.pendiente, 3),
      t('demo-tarea-autonomo', 'Probar la rutina autónoma de 30 s',
          'Ejecutar 10 repeticiones y registrar los resultados en la bitácora.',
          PrioridadTarea.media, EstadoTarea.pendiente, -1),
      t('demo-tarea-checklist', 'Imprimir el checklist pre-partido',
          'Dejar una copia en la caja de herramientas del equipo.',
          PrioridadTarea.baja, EstadoTarea.completada, null),
    ];
  }

  /// Ejemplo de transformación del apartado IV.6.3.4 de la tesis.
  static EntradaBitacora bitacora(String usuario) => EntradaBitacora(
        id: 'demo-bitacora-autonomo',
        fecha: DateTime(2025, 1, 15, 14, 30),
        autor: usuario,
        tipo: TipoBitacora.prueba,
        generadaPorIA: true,
        apunteOriginal: 'hoy probamos el autonomo, el robot se desvio como 5cm despues de 2 metros '
            'creo q es por el imu q esta mal calibrado, tmb las tracking wheels tienen '
            'mucho juego. mañana vamos a recalibrar todo y ajustar los tornillos',
        contenido: '''BITÁCORA TÉCNICA - PRUEBA DE NAVEGACIÓN AUTÓNOMA

Fecha: 15 de enero de 2025
Hora: 14:30

ACTIVIDAD REALIZADA:
Se ejecutaron pruebas de navegación autónoma del robot Jordan en trayectoria lineal de 2 metros de longitud.

OBSERVACIONES TÉCNICAS:
- Desviación lateral observada: aproximadamente 50 mm (5 cm)
- Distancia de prueba: 2000 mm (2 metros)
- Error relativo: 2.5% de la distancia recorrida

PROBLEMAS ENCONTRADOS:
1. Deriva lateral significativa durante navegación autónoma
2. Posible descalibración del sensor inercial (IMU)
3. Holgura mecánica detectada en las ruedas de seguimiento (tracking wheels)

SOLUCIONES PROPUESTAS:
1. Recalibración completa del giroscopio inercial mediante procedimiento estándar
2. Ajuste de tornillos de montaje de tracking wheels para eliminar juego mecánico
3. Verificación de alineación de ruedas de seguimiento respecto a ejes del robot

PRÓXIMOS PASOS:
- Ejecutar procedimiento de calibración de IMU
- Inspeccionar y ajustar montaje de tracking wheels
- Repetir pruebas de navegación para validar correcciones''',
      );

  /// Escritura multiruta (relativa a `Rutas.raiz`) que carga la demostración.
  static Map<String, Object?> cambiosCarga({required String usuario, required DateTime ahora}) {
    final bitacoraDemo = bitacora(usuario);
    return {
      for (final c in componentes(usuario, ahora)) 'inventario/${c.categoria}/${c.id}': c.toJson(),
      for (final t in tareas(usuario, ahora)) 'tareas/${t.id}': t.toJson(),
      'bitacoras/${bitacoraDemo.id}': bitacoraDemo.toJson(),
    };
  }

  /// Escritura multiruta que borra solo los datos de demostración (y los
  /// movimientos de stock que se hayan registrado sobre ellos).
  static Map<String, Object?> cambiosBorrado() {
    final ahora = DateTime.now();
    return {
      for (final c in componentes('', ahora)) ...{
        'inventario/${c.categoria}/${c.id}': null,
        'inventario_movimientos/${c.id}': null,
      },
      for (final t in tareas('', ahora)) 'tareas/${t.id}': null,
      'bitacoras/${bitacora('').id}': null,
    };
  }
}
