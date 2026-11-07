// Pruebas de las reglas de negocio usando una base de datos SQLite EN MEMORIA.
// Ejecutar con:  flutter test
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_piston_recepcion/data/base_datos.dart';
import 'package:el_piston_recepcion/data/modelos.dart';
import 'package:el_piston_recepcion/data/repositorio_taller.dart';

void main() {
  late AppDatabase db;
  late RepositorioTaller repo;
  late int vehiculoId;
  late int mecanicoId;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    repo = RepositorioTaller(db);
    final clienteId = await repo.crearCliente(nombre: 'Prueba', telefono: '55555555');
    vehiculoId = await repo.crearVehiculo(
        clienteId: clienteId, matricula: 'p000111', marca: 'Lada', modelo: '2105',
        anio: 1990, kilometraje: 1000);
    mecanicoId = (await repo.watchMecanicos().first).first.id;
  });

  tearDown(() => db.close());

  test('la matrícula se guarda en mayúsculas y no se repite', () async {
    final v = await repo.watchVehiculo(vehiculoId).first;
    expect(v!.matricula, 'P000111');
    expect(
      () => repo.crearVehiculo(
          clienteId: v.clienteId, matricula: 'P000111', marca: 'X', modelo: 'Y',
          anio: 2000, kilometraje: 0),
      throwsA(isA<ReglaNegocioException>()),
    );
  });

  test('usar un repuesto descuenta existencias y avisa si queda bajo', () async {
    final orden = await repo.crearOrden(
        vehiculoId: vehiculoId, mecanicoId: mecanicoId, problema: 'Prueba', kilometraje: 1200);
    final filtro = (await repo.watchRepuestos(busqueda: 'FIL-ACE').first).first;
    final r = await repo.usarRepuesto(orden, filtro.id, 5); // 8 -> 3 (mínimo 3)
    expect(r.repuesto.existencias, 3);
    expect(r.quedoBajo, isTrue);
    final bajos = await repo.watchRepuestosBajos().first;
    expect(bajos.any((x) => x.id == filtro.id), isTrue);
  });

  test('no se puede usar más repuesto del que hay', () async {
    final orden = await repo.crearOrden(
        vehiculoId: vehiculoId, mecanicoId: mecanicoId, problema: 'Prueba', kilometraje: 1200);
    final bujia = (await repo.watchRepuestos(busqueda: 'BUJ').first).first;
    expect(() => repo.usarRepuesto(orden, bujia.id, 99),
        throwsA(isA<ReglaNegocioException>()));
  });

  test('total = mano de obra + repuestos; pago en dos partes', () async {
    final orden = await repo.crearOrden(
        vehiculoId: vehiculoId, mecanicoId: mecanicoId, problema: 'Prueba', kilometraje: 1200);
    await repo.agregarTrabajo(orden, 'Cambio de aceite', 500);
    final aceite = (await repo.watchRepuestos(busqueda: 'ACE-5W30').first).first;
    await repo.usarRepuesto(orden, aceite.id, 2); // 2 x 1200
    var o = (await repo.watchOrden(orden).first)!;
    expect(o.total, 2900);

    await repo.registrarPago(orden, 1000);
    o = (await repo.watchOrden(orden).first)!;
    expect(o.saldo, 1900);
    expect(() => repo.registrarPago(orden, 5000), throwsA(isA<ReglaNegocioException>()));
    await repo.registrarPago(orden, 1900);
    o = (await repo.watchOrden(orden).first)!;
    expect(o.pagadaCompleta, isTrue);
  });

  test('flujo de estados y fecha de entrega', () async {
    final orden = await repo.crearOrden(
        vehiculoId: vehiculoId, mecanicoId: mecanicoId, problema: 'Prueba', kilometraje: 1200);
    for (var i = 0; i < 4; i++) {
      await repo.avanzarEstado(orden);
    }
    final o = (await repo.watchOrden(orden).first)!;
    expect(o.estado, EstadoOrden.entregada);
    expect(o.fechaEntrega, isNotNull);
    expect(() => repo.agregarTrabajo(orden, 'Tarde', 10),
        throwsA(isA<ReglaNegocioException>()));
  });

  test('cancelar devuelve los repuestos al inventario', () async {
    final orden = await repo.crearOrden(
        vehiculoId: vehiculoId, mecanicoId: mecanicoId, problema: 'Prueba', kilometraje: 1200);
    final filtro = (await repo.watchRepuestos(busqueda: 'FIL-ACE').first).first;
    await repo.usarRepuesto(orden, filtro.id, 2);
    await repo.cancelarOrden(orden);
    final despues = (await repo.watchRepuestos(busqueda: 'FIL-ACE').first).first;
    expect(despues.existencias, filtro.existencias);
  });

  test('un vehículo no puede tener dos órdenes abiertas', () async {
    await repo.crearOrden(
        vehiculoId: vehiculoId, mecanicoId: mecanicoId, problema: 'A', kilometraje: 1200);
    expect(
        () => repo.crearOrden(
            vehiculoId: vehiculoId, mecanicoId: mecanicoId, problema: 'B', kilometraje: 1300),
        throwsA(isA<ReglaNegocioException>()));
  });

  test('datos demo: deudores, carga y facturación', () async {
    await db.delete(db.vehiculos).go();
    await db.delete(db.clientes).go();
    await repo.cargarDatosDemo();
    final deudores = await repo.watchDeudores().first;
    expect(deudores.length, 1);
    expect(deudores.first.saldo, 5000);
    final carga = await repo.watchCargaMecanicos().first;
    expect(carga.fold<int>(0, (s, c) => s + c.abiertas), 2);
    final hoy = DateTime.now();
    final rep = await repo
        .watchFacturacion(hoy.subtract(const Duration(days: 30)), hoy)
        .first;
    expect(rep.cantidad, 2);
    expect(rep.facturado, 8000 + 4700);
    expect(rep.cobrado, 3000 + 4700);
  });
}
