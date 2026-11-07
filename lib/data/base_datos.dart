// =============================================================================
// base_datos.dart
// Clase principal de la base de datos Drift. Registra las tablas, define la
// versión del esquema, la estrategia de migración y los datos iniciales.
//
// El archivo `base_datos.g.dart` lo GENERA build_runner con el comando:
//   dart run build_runner build --delete-conflicting-outputs
// =============================================================================
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tablas.dart';

export 'tablas.dart';

part 'base_datos.g.dart';

@DriftDatabase(
  tables: [
    Clientes,
    Vehiculos,
    Mecanicos,
    Ordenes,
    Trabajos,
    Repuestos,
    OrdenRepuestos,
    Pagos,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Si no se pasa un executor se abre el archivo SQLite del teléfono.
  /// En las pruebas se pasa `NativeDatabase.memory()`.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _abrirConexion());

  @override
  int get schemaVersion => 1;

  /// `driftDatabase` (paquete drift_flutter) crea/abre el archivo
  /// `el_piston.sqlite` en la carpeta de documentos de la app. Los datos
  /// persisten aunque la app se cierre y no requieren internet.
  static QueryExecutor _abrirConexion() => driftDatabase(name: 'el_piston');

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _sembrarDatosIniciales();
        },
        beforeOpen: (OpeningDetails details) async {
          // SQLite no aplica las claves foráneas si no se activan.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Datos mínimos para empezar a trabajar: los dos mecánicos del taller y
  /// algunos repuestos de uso frecuente.
  Future<void> _sembrarDatosIniciales() async {
    await batch((b) {
      b.insertAll(mecanicos, [
        MecanicosCompanion.insert(nombre: 'Raúl Pérez'),
        MecanicosCompanion.insert(nombre: 'Yordan Díaz'),
      ]);
      b.insertAll(repuestos, [
        RepuestosCompanion.insert(
            codigo: 'ACE-5W30',
            nombre: 'Aceite de motor 5W-30 (1 L)',
            precioVenta: 1200,
            existencias: const Value(20),
            stockMinimo: const Value(5)),
        RepuestosCompanion.insert(
            codigo: 'FIL-ACE',
            nombre: 'Filtro de aceite',
            precioVenta: 900,
            existencias: const Value(8),
            stockMinimo: const Value(3)),
        RepuestosCompanion.insert(
            codigo: 'PAS-DEL',
            nombre: 'Juego de pastillas de freno delanteras',
            precioVenta: 3500,
            existencias: const Value(4),
            stockMinimo: const Value(2)),
        RepuestosCompanion.insert(
            codigo: 'BUJ-NGK',
            nombre: 'Bujía NGK',
            precioVenta: 450,
            existencias: const Value(2),
            stockMinimo: const Value(4)),
        RepuestosCompanion.insert(
            codigo: 'COR-DIS',
            nombre: 'Correa de distribución',
            precioVenta: 4800,
            existencias: const Value(3),
            stockMinimo: const Value(1)),
      ]);
    });
  }
}
