/// Piezas de interfaz compartidas por todas las pantallas.
///
/// Aquí viven los widgets que el tema de Material no cubre por sí solo y que se
/// repiten entre módulos: avisos (SnackBar), la vista reactiva del patrón MVVM,
/// los estados de carga/vacío/error, el diálogo de confirmación, tarjetas
/// pulsables, buscadores, filas de chips, etiquetas, avatares y encabezados.
/// Usarlos en lugar de componer a mano cada pantalla mantiene unificados los
/// espaciados, radios y colores definidos en `tema.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ucsa_prime/controllers/view_model.dart';
import 'package:ucsa_prime/models/usuario.dart';
import 'package:ucsa_prime/services/avisos.dart';
import 'package:ucsa_prime/ui/tema.dart';

// ---------------------------------------------------------------------------
// Avisos y vista reactiva (MVVM)
// ---------------------------------------------------------------------------

/// Clave del ScaffoldMessenger raíz: permite mostrar avisos aunque la pantalla
/// que inició la operación ya se haya cerrado.
final GlobalKey<ScaffoldMessengerState> mensajeroGlobal = GlobalKey<ScaffoldMessengerState>();

/// Muestra un aviso breve (SnackBar) en la raíz de la aplicación.
///
/// Los errores se muestran en rojo y duran más; si hay [accion] (p. ej.
/// «DESHACER»), el aviso queda visible unos segundos más para poder usarla.
void mostrarAviso(String mensaje, {bool error = false, SnackBarAction? accion}) {
  final mensajero = mensajeroGlobal.currentState;
  if (mensajero == null) return;
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? ColoresUcsa.peligro : ColoresUcsa.texto,
      action: accion,
      duration: Duration(seconds: error ? 6 : (accion != null ? 5 : 3)),
    ));
}

/// Muestra como SnackBar los avisos que publican los controladores a través
/// del canal global [Avisos] (los ViewModels no conocen el `BuildContext`).
class OyenteAvisos extends StatefulWidget {
  const OyenteAvisos({super.key, required this.child});

  final Widget child;

  @override
  State<OyenteAvisos> createState() => _OyenteAvisosState();
}

class _OyenteAvisosState extends State<OyenteAvisos> {
  StreamSubscription<Aviso>? _suscripcion;

  @override
  void initState() {
    super.initState();
    _suscripcion = Avisos.flujo.listen((aviso) => mostrarAviso(aviso.mensaje, error: aviso.esError));
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Vista que observa el flujo de estados de un ViewModel (MVVM reactivo): se
/// reconstruye con cada estado que emite el controlador.
class VistaReactiva<E> extends StatelessWidget {
  const VistaReactiva({super.key, required this.viewModel, required this.builder});

  final ViewModel<E> viewModel;
  final Widget Function(BuildContext context, E estado) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<E>(
      stream: viewModel.flujo,
      initialData: viewModel.estado,
      builder: (context, snapshot) => builder(context, snapshot.data ?? viewModel.estado),
    );
  }
}

/// Imagen de un asset decodificada al tamaño en que se muestra (ahorra memoria:
/// un fondo de 1360×1920 ocupa ~10 MB decodificado a tamaño completo).
ImageProvider imagenReducida(String asset, {required int ancho}) =>
    ResizeImage(AssetImage(asset), width: ancho, policy: ResizeImagePolicy.fit);

// ---------------------------------------------------------------------------
// Zonas seguras (edge-to-edge)
// ---------------------------------------------------------------------------
//
// Desde Android 15 la app se dibuja detrás de la barra de estado y de la barra
// de navegación del sistema. Los rellenos explícitos de las listas y hojas no
// suman esas barras por sí solos: estas funciones lo hacen en un único lugar.
//
// `MediaQuery.paddingOf(...).bottom` es la barra de navegación; vale 0 cuando
// el teclado está abierto, porque el teclado ya la cubre. El teclado
// (`viewInsets`) lo resuelve el `Scaffold` en las pantallas y [mostrarHoja] en
// las hojas inferiores, así que nunca se cuenta dos veces el mismo espacio.

/// Alto de la barra de navegación del sistema que tapa el contenido (0 si el
/// teclado está abierto o si el `Scaffold` ya la descontó).
double margenBarraNavegacion(BuildContext context) => MediaQuery.paddingOf(context).bottom;

/// Relleno de una lista de pantalla completa: margen lateral único y, al
/// final, [fin] más la barra de navegación del sistema. Por defecto deja libre
/// el botón flotante; las pantallas sin él pasan `fin: Espacio.l` o `Espacio.xl`.
///
/// Dentro de un `Scaffold` con `bottomNavigationBar` la barra ya está
/// descontada (el `Scaffold` quita ese relleno del cuerpo), así que no se
/// suma dos veces.
EdgeInsets rellenoLista(
  BuildContext context, {
  double arriba = Espacio.xxs,
  double fin = Espacio.finConBotonFlotante,
}) =>
    EdgeInsets.fromLTRB(Espacio.margen, arriba, Espacio.margen, fin + margenBarraNavegacion(context));

/// Relleno del contenido desplazable de una hoja inferior: margen lateral
/// único y, al final, aire por encima de la barra de navegación del sistema.
EdgeInsets rellenoHoja(BuildContext context) =>
    EdgeInsets.fromLTRB(Espacio.margen, 0, Espacio.margen, Espacio.l + margenBarraNavegacion(context));

/// Abre una hoja inferior con la configuración común de la app: altura
/// controlada por el contenido, sin invadir la barra de estado y elevada por
/// encima del teclado cuando se abre (así el campo enfocado queda a la vista).
/// El margen lateral y el inferior lo ponen [rellenoHoja] o [CuerpoHoja].
Future<T?> mostrarHoja<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Builder(builder: builder),
    ),
  );
}

/// Contenido desplazable de una hoja inferior con formulario (se abre con
/// [mostrarHoja]): margen lateral único y aire sobre la barra de navegación.
class CuerpoHoja extends StatelessWidget {
  const CuerpoHoja({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: rellenoHoja(context), child: child);
  }
}

// ---------------------------------------------------------------------------
// Estados de carga, error y vacío
// ---------------------------------------------------------------------------

/// Indicador de carga centrado, con un mensaje y un detalle opcional.
class EstadoCargando extends StatelessWidget {
  const EstadoCargando({super.key, this.mensaje = 'Cargando…', this.detalle});

  final String mensaje;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 3.5)),
            const SizedBox(height: Espacio.m),
            Text(mensaje, style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
            if (detalle != null) ...[
              const SizedBox(height: Espacio.xs),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mensaje centrado con ícono para listas vacías, búsquedas sin resultados y
/// errores de carga.
class EstadoMensaje extends StatelessWidget {
  const EstadoMensaje({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.color = ColoresUcsa.textoSuave,
    this.accion,
  });

  /// Error con acción opcional de reintento.
  const EstadoMensaje.error({super.key, required this.mensaje, this.accion})
      : icono = Icons.cloud_off_rounded,
        titulo = 'No se pudieron cargar los datos',
        color = ColoresUcsa.peligro;

  final IconData icono;
  final String titulo;
  final String mensaje;
  final Color color;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        // Abajo suma la barra de navegación: el mensaje nunca queda debajo de ella.
        padding: EdgeInsets.fromLTRB(
          Espacio.xl,
          Espacio.xl,
          Espacio.xl,
          Espacio.xl + margenBarraNavegacion(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: tonoSuave(color), shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(Espacio.m),
                child: Icon(icono, size: 40, color: color),
              ),
            ),
            const SizedBox(height: Espacio.m),
            Text(titulo, style: tema.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Espacio.xs),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave),
            ),
            if (accion != null) ...[const SizedBox(height: Espacio.l), accion!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diálogos y hojas inferiores
// ---------------------------------------------------------------------------

/// Confirmación para acciones destructivas o importantes. Devuelve `true` si
/// el usuario confirmó.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Eliminar',
  bool destructivo = true,
  IconData icono = Icons.delete_outline_rounded,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icono, color: destructivo ? ColoresUcsa.peligro : blueUcsa),
      title: Text(titulo, textAlign: TextAlign.center),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(
          style: destructivo ? FilledButton.styleFrom(backgroundColor: ColoresUcsa.peligro) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return resultado ?? false;
}

/// Título de una hoja inferior (formularios, detalle, historial), con un
/// subtítulo opcional.
class EncabezadoHoja extends StatelessWidget {
  const EncabezadoHoja(this.titulo, {super.key, this.subtitulo});

  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Espacio.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.headlineSmall),
          if (subtitulo != null) ...[
            const SizedBox(height: Espacio.xxs),
            Text(subtitulo!, style: tema.textTheme.bodyMedium?.copyWith(color: ColoresUcsa.textoSuave)),
          ],
        ],
      ),
    );
  }
}

/// Barra fija al pie de una pantalla con su acción principal (p. ej.
/// «Guardar entrada»). Se usa como `bottomNavigationBar` del `Scaffold`.
class BarraAccionInferior extends StatelessWidget {
  const BarraAccionInferior({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ColoresUcsa.fondo,
        border: Border(top: BorderSide(color: ColoresUcsa.borde)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Espacio.margen, Espacio.s, Espacio.margen, Espacio.s),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas visuales reutilizables
// ---------------------------------------------------------------------------

/// Tarjeta del tema con efecto de pulsación. Unifica el relleno, el borde y el
/// recorte de todas las tarjetas pulsables de las listas.
class TarjetaPulsable extends StatelessWidget {
  const TarjetaPulsable({
    super.key,
    required this.child,
    this.alPulsar,
    this.alMantener,
    this.relleno = Espacio.tarjeta,
    this.colorBorde,
  });

  final Widget child;
  final VoidCallback? alPulsar;
  final VoidCallback? alMantener;
  final EdgeInsetsGeometry relleno;

  /// Borde resaltado (p. ej. stock bajo); por defecto, el borde del tema.
  final Color? colorBorde;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: colorBorde == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radios.grande),
              side: BorderSide(color: colorBorde!, width: 1.4),
            ),
      child: InkWell(
        onTap: alPulsar,
        onLongPress: alMantener,
        child: Padding(padding: relleno, child: child),
      ),
    );
  }
}

/// Ícono sobre un cuadrado redondeado con el tono suave de su color (módulos,
/// categorías del inventario, encabezados de tarjetas).
class IconoEnCaja extends StatelessWidget {
  const IconoEnCaja(this.icono, {super.key, required this.color, this.tamano = 24});

  final IconData icono;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: tonoSuave(color, alfa: 28), borderRadius: BorderRadius.circular(Radios.medio)),
      child: Padding(
        padding: EdgeInsets.all(tamano * 0.4),
        child: Icon(icono, color: color, size: tamano),
      ),
    );
  }
}

/// Campo de búsqueda con botón para limpiarlo. Al limpiar, llama a
/// [alCambiar] con el texto vacío para que el ViewModel quite el filtro.
class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({super.key, required this.controlador, required this.alCambiar, required this.pista});

  final TextEditingController controlador;
  final ValueChanged<String> alCambiar;
  final String pista;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espacio.margen, Espacio.xxs, Espacio.margen, Espacio.xs),
      child: TextField(
        controller: controlador,
        onChanged: alCambiar,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: pista,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controlador,
            builder: (context, valor, _) => valor.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      controlador.clear();
                      alCambiar('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

/// Fila de chips con desplazamiento horizontal (filtros por categoría o tipo).
///
/// Por defecto ocupa todo el ancho de la pantalla y deja el margen lateral
/// como relleno interno: los chips se desplazan hasta el borde, pero el
/// primero y el último quedan alineados con el resto del contenido.
class FilaDeChips extends StatelessWidget {
  const FilaDeChips({
    super.key,
    required this.chips,
    this.relleno = const EdgeInsets.symmetric(horizontal: Espacio.margen),
    this.alto = 48,
  });

  final List<Widget> chips;

  /// Relleno horizontal de la fila (cero si ya está dentro de un contenido con margen).
  final EdgeInsetsGeometry relleno;

  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: relleno,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: Espacio.xs),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}

/// Recuadro de aviso dentro de una pantalla (error de ingreso, texto generado
/// por IA…), con el tono suave de su color y una acción opcional.
class RecuadroAviso extends StatelessWidget {
  const RecuadroAviso({super.key, required this.icono, required this.color, required this.mensaje, this.accion});

  final IconData icono;
  final Color color;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tonoSuave(color, alfa: 20),
        borderRadius: BorderRadius.circular(Radios.medio),
        border: Border.all(color: tonoSuave(color, alfa: 70)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(Espacio.s, Espacio.s, accion == null ? Espacio.s : Espacio.xxs, Espacio.s),
        child: Row(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: Espacio.s),
            Expanded(
              child: Text(mensaje, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
            ),
            if (accion != null) accion!,
          ],
        ),
      ),
    );
  }
}

/// Etiqueta compacta de color (prioridad, estado, tipo…).
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, required this.color, this.icono, this.relleno = false});

  final String texto;
  final Color color;
  final IconData? icono;

  /// Fondo lleno del color y texto blanco (para resaltar, p. ej. «vencida»).
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final colorTexto = relleno ? Colors.white : color;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: relleno ? color : tonoSuave(color),
        borderRadius: BorderRadius.circular(Radios.chico),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.xs, vertical: 3),
        // Un solo Text (con el ícono como WidgetSpan): se recorta con "…" si el
        // espacio es limitado y funciona también sin restricciones de ancho.
        child: Text.rich(
          TextSpan(
            children: [
              if (icono != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: Espacio.xxs),
                    child: Icon(icono, size: 14, color: colorTexto),
                  ),
                ),
              TextSpan(text: texto),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorTexto, height: 1.2),
        ),
      ),
    );
  }
}

/// Avatar circular con las iniciales de un integrante.
class AvatarIniciales extends StatelessWidget {
  const AvatarIniciales(this.nombre, {super.key, this.radio = 14, this.color = blueUcsa});

  final String nombre;
  final double radio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: tonoSuave(color, alfa: 30),
      child: Text(
        inicialesDe(nombre),
        style: TextStyle(
          fontFamily: ucsaFont,
          fontWeight: FontWeight.w700,
          fontSize: radio * 0.85,
          color: color,
        ),
      ),
    );
  }
}

/// Avatar de un integrante seguido de su nombre (autor, responsable).
class AutorConAvatar extends StatelessWidget {
  const AutorConAvatar(this.nombre, {super.key, this.color = blueUcsa});

  final String nombre;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarIniciales(nombre, radio: 11, color: color),
        const SizedBox(width: Espacio.xs),
        Flexible(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

/// Encabezado de sección con acción opcional ("Ver todo").
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion(this.titulo, {super.key, this.accion, this.alPulsar});

  final String titulo;
  final String? accion;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.l, bottom: Espacio.xs),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(child: Text(titulo, style: Theme.of(context).textTheme.titleMedium)),
            if (accion != null)
              TextButton(
                onPressed: alPulsar,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(accion!),
              ),
          ],
        ),
      ),
    );
  }
}
