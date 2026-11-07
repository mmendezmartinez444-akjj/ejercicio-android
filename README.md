 "Pistón Recepción"

Aplicación Flutter (Android) para gestionar el taller automotriz **El Pistón**: clientes, vehículos,
órdenes de servicio, trabajos, repuestos e inventario, pagos parciales y reportes. Funciona
**sin conexión**: todos los datos se guardan en una base SQLite local mediante Drift.


## Enfoque de UX/UI

### Idea general
- **Navegación tipo HUB**: la pantalla de inicio saluda ("Buenos días / Buenas tardes / Buenas
  noches" según la hora), muestra un resumen del día y una **cuadrícula de accesos grandes**
  (`GridView`): Nueva orden, Órdenes, Clientes, Inventario, Reportes y Mecánicos. Cada acceso
  abre su pantalla con `Navigator.push`; para volver se usa la flecha atrás. No hay barra inferior
  ni menú lateral: menos opciones a la vista, menos confusión.
- **Ajustes** (icono de engranaje del inicio): hoja inferior (`showModalBottomSheet`) con
  *Cargar datos de ejemplo* y *Gestionar mecánicos*.
- **Nueva orden como asistente** (`Stepper` vertical de 5 pasos): 1) Cliente (buscar o crear en
  línea; si se escribe una matrícula aparecen los vehículos que coinciden y se salta al paso 3),
  2) Vehículo (elegir uno del cliente o registrar uno nuevo), 3) Problema y kilometraje
  (precargado con el último registrado), 4) Mecánico (`RadioListTile` con su carga y una etiqueta
  "Sugerido" en el menos ocupado), 5) Confirmar (resumen). Cada paso se valida antes de avanzar.
  Al crear la orden se abre directamente su detalle.
- **Detalle de la orden**: cabecera con vehículo/cliente/mecánico, **línea de tiempo vertical**
  del flujo de estados (pasos completados con check, el actual resaltado), tarjetas expandibles
  (`ExpansionTile`) de Trabajos, Repuestos y Pagos, y un **"ticket" de totales** con aspecto de
  recibo. Abajo, un **botón grande con la siguiente acción** ("Pasar a diagnóstico", "Pasar a
  reparación", "Marcar lista para entregar", "Entregar al cliente"). El menú ⋮ permite volver al
  estado anterior, cambiar mecánico, editar el problema y cancelar.
- **Formularios en `AlertDialog`** con validación por campo; los errores de negocio (matrícula
  repetida, monto mayor que el saldo…) se muestran *dentro* del diálogo sin perder lo escrito.
- **Confirmaciones** antes de cancelar órdenes o eliminar trabajos, repuestos, pagos, clientes y
  vehículos. **Aviso ámbar** inmediato cuando un repuesto queda por agotarse al usarlo
  ("Quedan N de X: hay que comprar").

### Paleta de colores (tema claro)

| Rol | Hex | Uso |
|---|---|---|
| Fondo | `#F6F8F7` | Fondo de las pantallas y del AppBar |
| Tarjetas | `#FFFFFF` | Tarjetas, campos de texto, ticket |
| Primario (verde azulado) | `#0D9488` | Botones principales, FAB, chips seleccionados, barras |
| Primario oscuro | `#115E59` | Iconos, cifras destacadas, SnackBar de éxito |
| Acento coral | `#F97361` | Saldos pendientes, deudores, botón "Entregar al cliente" |
| Aviso ámbar | `#F59E0B` | Stock por agotarse |
| Error | `#DC2626` | Errores y acciones destructivas |
| Texto | `#1F2937` | Texto principal |
| Texto secundario | `#6B7280` | Detalles, fechas, ayudas |
| Borde | `#E5E7EB` | Borde sutil de tarjetas (sin elevación) |

Estados de la orden como **píldoras pastel con texto oscuro** (fondo / texto):
recibida `#E0E7FF`/`#3730A3`, en diagnóstico `#E0F2FE`/`#075985`, en reparación
`#FEF3C7`/`#92400E`, lista para entregar `#DCFCE7`/`#166534`, entregada `#F3F4F6`/`#374151`,
cancelada `#FEE2E2`/`#991B1B`. Cada estado tiene además su icono, para no depender solo del color.

### Tipografía y forma
- Fuente **Poppins** (pesos 400, 500, 600 y 700) en todo el tema, incluida en `assets/fonts`
  (no se descarga: la app es 100 % offline). Licencia OFL en `assets/fonts/OFL-poppins.txt`.
- **Bordes muy redondeados** (radio 20 en tarjetas, 16 en campos y botones, 30 en píldoras y
  buscadores), tarjetas **sin elevación** con borde sutil y mucho espacio en blanco.

### Accesibilidad y decisiones
- Contraste alto: texto oscuro sobre fondos pastel; los estados combinan color + icono + texto.
- Botones grandes (56 px el de la acción principal) y zonas táctiles amplias en la cuadrícula.
- `tooltip` en todos los `IconButton` (lectores de pantalla y pulsación larga).
- Textos y formatos en español (`locale: es`, calendario incluido); moneda CUP.
- Todo es reactivo (`StreamBuilder`): al registrar un pago se actualizan solos el ticket, el
  saldo, los deudores y el resumen del inicio.
- Los `Stream` se crean una sola vez por pantalla (campos `late final`) o se recrean solo al
  cambiar el filtro/búsqueda, para evitar parpadeos.

## Estructura de carpetas

```
lib/
├── main.dart                    # Abre la BD, crea el repositorio, MaterialApp (tema, idioma)
├── data/                        # Núcleo común (no cambia entre soluciones)
│   ├── tablas.dart              # Esquema Drift + enum EstadoOrden
│   ├── base_datos.dart          # AppDatabase (+ base_datos.g.dart generado)
│   ├── modelos.dart             # OrdenResumen, Deudor, CargaMecanico, ReglaNegocioException…
│   ├── repositorio_taller.dart  # Consultas y reglas de negocio
│   └── taller_scope.dart        # InheritedWidget que entrega el repositorio
├── utils/formato.dart           # dinero(), fecha(), leerEntero()…
└── ui/
    ├── tema.dart                # Paleta, ThemeData (Poppins), estilos de estado, helpers
    ├── widgets/
    │   ├── tarjeta.dart              # Tarjeta, TituloSeccion, BarraNivel
    │   ├── estados_vista.dart        # Cargando, MensajeVacio, MensajeError
    │   ├── campo_busqueda.dart       # Buscador redondeado
    │   ├── pildora_estado.dart       # Píldora pastel del estado
    │   ├── mensajes.dart             # SnackBars, confirmar(), aviso de stock, ejecutarAccion()
    │   ├── tarjeta_orden.dart        # Tarjeta resumen de una orden
    │   ├── linea_tiempo_estados.dart # Línea de tiempo vertical del flujo
    │   ├── ticket_totales.dart       # Ticket de totales tipo recibo
    │   ├── dialogos.dart             # Formularios: cliente, vehículo, repuesto, cantidad, texto
    │   └── dialogos_orden.dart       # Formularios: trabajo, pago, usar repuesto
    └── pantallas/
        ├── inicio_pantalla.dart          # Hub: saludo, resumen, cuadrícula, carga
        ├── nueva_orden_pantalla.dart     # Asistente Stepper de 5 pasos
        ├── ordenes_pantalla.dart         # Lista con filtros (ChoiceChips) y búsqueda
        ├── detalle_orden_pantalla.dart   # Línea de tiempo, trabajos, repuestos, pagos, ticket
        ├── clientes_pantalla.dart        # Lista de clientes con saldo
        ├── detalle_cliente_pantalla.dart # Ficha: llamar, vehículos horizontales, historial
        ├── vehiculo_pantalla.dart        # Datos y historial de servicios del vehículo
        ├── inventario_pantalla.dart      # Repuestos con barra de nivel y reabastecer
        ├── reportes_pantalla.dart        # Facturación, deudores, carga, stock bajo
        └── mecanicos_pantalla.dart       # Añadir, renombrar, activar/desactivar
```

## Capturas

Las capturas de la aplicación en uso se guardan en la carpeta [`capturas/`](capturas/)
(ver `capturas/LEEME.md` con los nombres sugeridos). Para obtener datos rápidamente use
**Ajustes → Cargar datos de ejemplo** en la pantalla de inicio.

## Cómo ejecutar el proyecto

1. Abrir la carpeta del proyecto en **Android Studio** (con los plugins *Flutter* y *Dart* instalados): `File > Open` y elegir la carpeta que contiene `pubspec.yaml`.
2. Descargar dependencias: `flutter pub get` (o el botón *Pub get* que aparece arriba del `pubspec.yaml`).
3. **Generar el código de Drift** (obligatorio la primera vez y cada vez que se cambie `tablas.dart` o `base_datos.dart`):

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

   Esto crea `lib/data/base_datos.g.dart` (clases `Cliente`, `ClientesCompanion`, `$ClientesTable`, etc.).
4. Elegir un emulador o teléfono Android y pulsar **Run** (`flutter run`).
5. Pruebas de reglas de negocio: `flutter test`.

> Si Android Studio no reconoce la carpeta `android/` (versión de Flutter muy distinta), ejecute `flutter create --platforms=android .` dentro del proyecto: regenera solo los archivos de plataforma que falten y no toca `lib/`.

Primer uso: en el menú de la app está **Cargar datos de ejemplo**, que crea 3 clientes, 4 vehículos y 4 órdenes en distintos estados para probar todas las pantallas.

## Decisiones de diseño comunes (modelo de datos y reglas)

**Tecnología.** Flutter + Dart, persistencia con **Drift** sobre SQLite (paquete `drift_flutter`). La base de datos es un archivo local (`el_piston.sqlite`), así que la app funciona **sin internet** y conserva todo aunque se cierre. No se usa ningún servicio en la nube. Las fuentes tipográficas están incluidas en `assets/fonts` (no se descargan), por la misma razón.

**Arquitectura en capas.**
- `lib/data/tablas.dart`: esquema (8 tablas).
- `lib/data/base_datos.dart`: clase `AppDatabase` (Drift), migración y datos iniciales.
- `lib/data/repositorio_taller.dart`: todas las consultas y **reglas de negocio**. La interfaz nunca escribe SQL.
- `lib/data/modelos.dart`: clases de vista (`OrdenResumen`, `Deudor`, `CargaMecanico`…) y la excepción `ReglaNegocioException`.
- `lib/data/taller_scope.dart`: `InheritedWidget` que entrega el repositorio a todas las pantallas.
- `lib/ui/...`: pantallas y widgets (lo que cambia entre las tres soluciones).

**Reactividad.** Las consultas `watch...()` devuelven `Stream`. Las pantallas usan `StreamBuilder`; al guardar un pago, por ejemplo, el total, el saldo, la lista de deudores y el tablero se actualizan solos sin recargar manualmente.

**Modelo de datos.**

| Tabla | Campos principales | Relación |
|---|---|---|
| clientes | nombre, teléfono, dirección (opcional) | 1 cliente → N vehículos |
| vehiculos | matrícula (única), marca, modelo, año, kilometraje | 1 vehículo → N órdenes |
| mecanicos | nombre, activo | 1 mecánico → N órdenes |
| ordenes | vehículo, mecánico, fecha de entrada, problema, estado, km de entrada, fecha de entrega | |
| trabajos | orden, descripción, precio de mano de obra | 1 orden → N trabajos |
| repuestos | código (único), nombre, precio de venta, existencias, stock mínimo | |
| orden_repuestos | orden, repuesto, cantidad, precio unitario del momento | N:M órdenes–repuestos |
| pagos | orden, monto, fecha, método | 1 orden → N pagos |

**Decisiones tomadas donde el enunciado deja puntos abiertos.**
1. *Estados*: recibida → en diagnóstico → en reparación → lista para entregar → entregada; desde cualquier estado abierto se puede **cancelar**. Se permite retroceder un paso para corregir errores. Al pasar a *entregada* se guarda la fecha de entrega.
2. Las órdenes **entregadas o canceladas no se pueden editar** (trabajos, repuestos, mecánico).
3. Un vehículo **no puede tener dos órdenes abiertas** a la vez.
4. Al crear la orden se registra el **kilometraje de entrada** y se actualiza el "último kilometraje" del vehículo.
5. Al usar un repuesto se valida que haya existencias y se **descuentan en una transacción**. Si se quita de la orden, las unidades vuelven al inventario. Se guarda el **precio del momento** para que el historial no cambie si luego sube el precio.
6. *Stock bajo*: cada repuesto tiene su **stock mínimo** configurable. Si `existencias <= mínimo` aparece en la alerta del inicio y en el reporte; además, al usar un repuesto que cae a ese nivel se muestra un aviso inmediato.
7. *Cancelar*: devuelve los repuestos al inventario. No se permite cancelar una orden con pagos (habría que devolver dinero); primero se eliminan los pagos.
8. *Pagos*: se admiten **pagos parciales** (abonos) en cualquier estado no cancelado; no se puede pagar más que el saldo. Total = mano de obra + repuestos; saldo = total − pagado.
9. *Deuda del cliente*: se cuenta el saldo de las órdenes **terminadas** (lista para entregar o entregada); en las órdenes en proceso el total todavía puede cambiar. Se puede entregar el carro con saldo pendiente (el cliente paga en dos partes).
10. *Facturación de un período*: suma de los totales de las órdenes **entregadas** en el período (desglosado en mano de obra y repuestos), y aparte lo **cobrado** (pagos recibidos) en ese período.
11. Matrículas y códigos de repuesto se guardan en mayúsculas y son únicos. No se borra un cliente con vehículos ni un vehículo con historial.
12. Moneda: CUP. Dos mecánicos precargados (editables) y cinco repuestos de ejemplo.
