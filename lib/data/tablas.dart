// =============================================================================
// tablas.dart
// Definición del esquema de la base de datos local (SQLite) usando Drift.
// Cada clase que extiende `Table` se convierte en una tabla SQL. Drift genera
// (con build_runner) la clase de datos, el "Companion" para inserciones y
// actualizaciones, y todo el SQL necesario en `base_datos.g.dart`.
// =============================================================================
import 'package:drift/drift.dart';

/// Estados por los que pasa una orden de servicio.
/// IMPORTANTE: se guardan en la BD como su índice (intEnum), por eso el orden
/// de los valores NO debe cambiarse una vez la app esté en uso.
enum EstadoOrden {
  recibida, // 0
  diagnostico, // 1
  reparacion, // 2
  lista, // 3  lista para entregar
  entregada, // 4
  cancelada, // 5
}

/// Datos del cliente. La dirección es opcional ("a veces una dirección").
@DataClassName('Cliente')
class Clientes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 120)();
  TextColumn get telefono => text().withLength(min: 1, max: 30)();
  TextColumn get direccion => text().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}

/// Un cliente puede tener varios vehículos (relación 1:N).
@DataClassName('Vehiculo')
class Vehiculos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clienteId => integer().references(Clientes, #id)();
  TextColumn get matricula => text().withLength(min: 1, max: 15).unique()();
  TextColumn get marca => text().withLength(min: 1, max: 60)();
  TextColumn get modelo => text().withLength(min: 1, max: 60)();
  IntColumn get anio => integer()();

  /// Kilometraje con el que llegó la última vez (se actualiza en cada orden).
  IntColumn get kilometraje => integer().withDefault(const Constant(0))();
}

/// Mecánicos del taller (el taller tiene dos, pero se permite gestionar más).
@DataClassName('Mecanico')
class Mecanicos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text().withLength(min: 1, max: 80)();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

/// Cada visita de un vehículo es una orden de servicio.
@DataClassName('Orden')
class Ordenes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get vehiculoId => integer().references(Vehiculos, #id)();
  IntColumn get mecanicoId => integer().references(Mecanicos, #id)();
  DateTimeColumn get fechaEntrada => dateTime()();
  TextColumn get problema => text().withLength(min: 1, max: 500)();
  IntColumn get estado => intEnum<EstadoOrden>()();

  /// Kilometraje registrado al entrar (queda en el historial de la orden).
  IntColumn get kilometrajeEntrada => integer().withDefault(const Constant(0))();

  /// Se llena automáticamente cuando la orden pasa a "entregada".
  DateTimeColumn get fechaEntrega => dateTime().nullable()();
}

/// Trabajos realizados (mano de obra) dentro de una orden.
@DataClassName('Trabajo')
class Trabajos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId =>
      integer().references(Ordenes, #id, onDelete: KeyAction.cascade)();
  TextColumn get descripcion => text().withLength(min: 1, max: 200)();
  RealColumn get precio => real()();
}

/// Inventario de repuestos.
@DataClassName('Repuesto')
class Repuestos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get codigo => text().withLength(min: 1, max: 30).unique()();
  TextColumn get nombre => text().withLength(min: 1, max: 120)();
  RealColumn get precioVenta => real()();
  IntColumn get existencias => integer().withDefault(const Constant(0))();

  /// Umbral de alerta: si existencias <= stockMinimo, el repuesto está
  /// "por agotarse" y se avisa al dueño.
  IntColumn get stockMinimo => integer().withDefault(const Constant(3))();
}

/// Repuestos usados en una orden (tabla intermedia N:M Ordenes–Repuestos).
/// Se guarda el precio unitario del momento para que el historial no cambie
/// si luego se modifica el precio de venta en el inventario.
@DataClassName('RepuestoUsado')
class OrdenRepuestos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId =>
      integer().references(Ordenes, #id, onDelete: KeyAction.cascade)();
  IntColumn get repuestoId => integer().references(Repuestos, #id)();
  IntColumn get cantidad => integer()();
  RealColumn get precioUnitario => real()();
}

/// Pagos (abonos) de una orden. Permite pagar en varias partes.
@DataClassName('Pago')
class Pagos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ordenId =>
      integer().references(Ordenes, #id, onDelete: KeyAction.cascade)();
  RealColumn get monto => real()();
  DateTimeColumn get fecha => dateTime()();
  TextColumn get metodo =>
      text().withDefault(const Constant('Efectivo'))();
}
