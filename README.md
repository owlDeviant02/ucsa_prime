# UCSA Prime — Aplicación de gestión del equipo VEX U

Aplicación móvil para la gestión técnica del equipo **UCSA Prime** (Universidad del Cono Sur de las
Américas), desarrollada como parte del Trabajo Final de Grado sobre el robot **Jordan** (VEX U,
temporada *High Stakes* 2024-2025). Corresponde al cuarto objetivo específico de la tesis: una
aplicación para la gestión del inventario y la trazabilidad del proyecto, con sincronización de datos
en tiempo real.

El programa del robot está publicado en el repositorio
[owlDeviant02/jordan](https://github.com/owlDeviant02/jordan).

## Funciones

- **Inicio:** estado de la conexión, estadísticas en tiempo real, componentes con stock bajo y
  actividad reciente del equipo (quién hizo qué y cuándo).
- **Inventario:** componentes por categoría, búsqueda, alertas de stock bajo e historial de
  movimientos. Los cambios de cantidad usan transacciones (`runTransaction`), de modo que dos
  integrantes pueden descontar el mismo componente a la vez sin perder actualizaciones.
- **Tareas:** tablero Pendientes / En progreso / Completadas, con prioridad, responsable y vencimiento.
- **Checklist previo al partido:** verificación por robot, con registro e historial.
- **Bitácora técnica con IA:** el integrante escribe o dicta un apunte informal y Gemini lo reescribe
  en versión formal y técnica, sin agregar información (los mismos hechos y valores, en el mismo orden).
  El texto se revisa antes de guardarlo y la entrada conserva el apunte original y la marca
  `generadaPorIA`.
- **Funcionamiento sin conexión:** caché local de Firebase; las escrituras se sincronizan al reconectar.
- **Ingreso con huella:** después del primer ingreso con contraseña, la app ofrece activar la huella. Las
  credenciales quedan cifradas solo en el teléfono (almacén seguro de Android) y no se guardan en el
  gestor de contraseñas de Google.

## Arquitectura

- **Flutter** (Dart), patrón **MVVM**: `lib/models` (modelos con `toJson`/`fromJson`),
  `lib/controllers` (ViewModels que exponen `Stream`s) y `lib/views` (vistas que solo observan esos
  flujos e invocan acciones).
- **Firebase Realtime Database** como base de datos NoSQL en tiempo real, con persistencia offline y
  `keepSynced` sobre inventario, tareas y bitácoras.
- **Firebase AI Logic** (Gemini Developer API) para la IA, con una «carrera escalonada» entre tres
  modelos: se consulta `gemini-3.8-flash`; si en 2,5 s todavía no empezó a responder, o si falla, se
  suma `gemini-3-flash-preview`, y luego `gemini-3.5-flash-lite`; se usa la respuesta que llegue primero (la otra se
  cancela). La respuesta se muestra en streaming a medida que se genera.
- **Firebase App Check** para proteger las llamadas a Gemini.

Estructura de datos (`ucsa-prime-robotics/`):

```
inventario/{categoria}/{id}      componentes
inventario_movimientos/{id}      historial de cambios de stock
tareas/{id}                      tareas del equipo
bitacoras/{id}                   entradas de la bitácora técnica
checklists/…                     verificaciones registradas
usuarios/{id}                    perfil público (nombre y último acceso)
actividad/{id}                   registro de actividad
```

## Estructura del código

```
lib/
├── main.dart               Punto de entrada: inicializa Firebase y arranca la app.
├── app.dart                MaterialApp: tema, idioma español, avisos globales y pantalla inicial.
├── backend/
│   └── firebase_options.example.dart   Plantilla de configuración de Firebase (sin credenciales).
├── models/                 Modelos (capa Model): datos inmutables con toJson/fromJson.
│   ├── json.dart                 Conversión tolerante de los valores de Firebase.
│   ├── componente_inventario.dart  Componentes, categorías y movimientos de stock.
│   ├── tarea.dart                Tareas, prioridades, estados y vencimientos.
│   ├── checklist.dart            Plantillas por robot y registros del checklist.
│   ├── bitacora.dart             Entradas de la bitácora (título, vista previa, marca de IA).
│   ├── actividad.dart            Registro de actividad del equipo.
│   └── usuario.dart              Integrante con sesión iniciada.
├── controllers/            ViewModels (capa ViewModel): estado de cada pantalla como Stream.
│   ├── view_model.dart           Clase base ViewModel<E>.
│   ├── sesion_controller.dart    Ingreso y cierre de sesión.
│   ├── dashboard_controller.dart Resumen del inicio.
│   ├── inventario_controller.dart  Inventario, filtros y transacciones de stock.
│   ├── tareas_controller.dart    Tablero de tareas.
│   ├── checklist_controller.dart Checklist previo al partido e historial.
│   └── bitacora_controller.dart  Lista de la bitácora y editor con IA.
├── services/               Acceso a servicios externos y utilidades de la app.
│   ├── firebase_service.dart     Rutas, inicialización, caché offline y App Check.
│   ├── gemini_service.dart       Gemini (Firebase AI Logic) con carrera escalonada.
│   ├── huella_service.dart       Ingreso con huella (credenciales cifradas en el teléfono).
│   ├── dictado_service.dart      Dictado por voz para los apuntes.
│   ├── avisos.dart               Canal global de avisos para la interfaz.
│   └── datos_demo.dart           Datos de demostración (prefijo «demo-»).
├── ui/                     Sistema visual compartido.
│   ├── tema.dart                 Paleta, escala de espaciados, radios, tipografía y ThemeData.
│   ├── componentes.dart          Piezas comunes: estados vacío/carga/error, diálogos, tarjetas,
│   │                             buscador, chips, etiquetas, avatares y encabezados.
│   ├── modulos.dart              Color e ícono de cada módulo, categoría, prioridad y estado.
│   └── fondo_ucsa.dart           Fondo animado institucional del ingreso.
├── utils/
│   └── fechas.dart               Formatos de fecha en español y tiempo relativo.
└── views/                  Pantallas (capa View): solo observan a su ViewModel.
    ├── ingreso/                  Presentación, ingreso y huella.
    ├── inicio/                   Resumen, módulos, stock bajo y actividad.
    ├── inventario/               Lista, detalle del componente y formulario.
    ├── tareas/                   Tablero y formulario de tareas.
    ├── checklist/                Checklist por robot e historial.
    └── bitacora/                 Lista, detalle y editor con IA.
test/                       Pruebas de modelos, fechas, configuración de Gemini e interfaz.
tool/generar_icono.py       Generador del ícono de Android.
assets/                     Logo, imágenes de los robots y fondos de las tarjetas.
```

### Sistema visual

Todas las pantallas usan los valores de `lib/ui/tema.dart`: el azul de marca (`#364CE4`) como color
primario, un color por módulo (inventario verde azulado, tareas azul, checklist violeta, bitácora
ámbar), colores de estado con contraste suficiente sobre blanco, espaciados en múltiplos de 4
(4/8/12/16/24/32) y radios de 8 (etiquetas), 12 (campos, botones y chips), 16 (tarjetas) y 24
(diálogos y hojas inferiores). Los títulos y etiquetas usan la tipografía Rajdhani; el texto, la
fuente del sistema. Los estilos de botones, tarjetas, campos, chips, diálogos y hojas se definen una
sola vez en el tema.

## Configuración

Este repositorio **no incluye credenciales**. Para compilar la aplicación se necesita un proyecto de
Firebase propio:

1. Crear un proyecto en la [consola de Firebase](https://console.firebase.google.com/) y registrar una
   app Android con el paquete `com.ucsa.app`.
2. Crear la base de datos de **Realtime Database**.
3. Generar la configuración local con la [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):

   ```bash
   flutterfire configure --out=lib/backend/firebase_options.dart
   ```

   Esto crea `lib/backend/firebase_options.dart` y `android/app/google-services.json`, que están
   excluidos del repositorio por `.gitignore`. Como alternativa, copiar
   `lib/backend/firebase_options.example.dart` con el nombre `firebase_options.dart` y completar los
   valores del proyecto.
4. En **Firebase AI Logic**, habilitar la Gemini Developer API.
5. **App Check:** en la consola, *App Check → Apps → Administrar tokens de depuración*, generar un
   token y compilar con él:

   ```bash
   flutter build apk --release --dart-define=APP_CHECK=debug --dart-define=APP_CHECK_DEBUG_TOKEN=<token>
   ```

   El token se pasa al compilar y no se guarda en el código. Opcionalmente,
   `--dart-define=GEMINI_PRIMERO=<modelo>` fija el modelo de Gemini que se prueba primero (útil si el
   principal está saturado); si un modelo no responde a tiempo, la app pasa al siguiente.
6. Las cuentas de ingreso son nodos `/{usuario}` en la raíz de la base, con los campos `name` y
   `password`.

## Ícono

El ícono se genera a partir del logo de UCSA Prime (`assets/logo.png`, el hexágono blanco) sobre un
degradado del azul de la app, con `python tool/generar_icono.py`.

## Pruebas

```bash
flutter analyze
flutter test
```

## Limitaciones conocidas

- El ingreso no usa Firebase Authentication: las cuentas se validan contra la base de datos, por lo que
  las reglas de seguridad deben permitir esa lectura. Migrar el ingreso a Firebase Authentication es
  la mejora de seguridad pendiente.
- Solo se probó en Android.

## Autores

Daniel González Romero y María Cecilia Cantero Brítez — Equipo UCSA Prime, Universidad del Cono Sur de
las Américas.
