// =============================================================================
// repositorio_taller.dart
// Capa de acceso a datos y REGLAS DE NEGOCIO del taller. Las pantallas nunca
// escriben SQL: llaman a estos métodos. Las consultas "watch..." devuelven
// Streams: cuando cambia una tabla, Drift vuelve a emitir el resultado y la
// interfaz se actualiza sola (programación reactiva).
// =============================================================================
import 'package:drift/drift.dart';

import 'base_datos.dart';
import 'modelos.dart';

class RepositorioTaller {
  final AppDatabase db;
  RepositorioTaller(this.db);

  // ---------------------------------------------------------------------------
  // SQL base de una orden con totales calculados con subconsultas.
  // Nota: Drift nombra tablas y columnas en snake_case (fechaEntrada ->
  // fecha_entrada, OrdenRepuestos -> orden_repuestos).
  // ---------------------------------------------------------------------------
  static const String _sqlOrden = '''
SELECT o.id, o.fecha_entrada, o.fecha_entrega, o.estado, o.problema,
       o.kilometraje_entrada, o.vehiculo_id,
       v.matricula, v.marca, v.modelo, v.anio, v.cliente_id,
       c.nombre AS cliente_nombre, c.telefono AS cliente_telefono,
       o.mecanico_id, m.nombre AS mecanico_nombre,
       (SELECT COALESCE(SUM(t.precio), 0.0)
          FROM trabajos t WHERE t.orden_id = o.id) AS mano_obra,
       (SELECT COALESCE(SUM(r.cantidad * r.precio_unitario), 0.0)
          FROM orden_repuestos r WHERE r.orden_id = o.id) AS total_repuestos,
       (SELECT COALESCE(SUM(p.monto), 0.0)
          FROM pagos p WHERE p.orden_id = o.id) AS pagado
  FROM ordenes o
  JOIN vehiculos v ON v.id = o.vehiculo_id
  JOIN clientes c ON c.id = v.cliente_id
  JOIN mecanicos m ON m.id = o.mecanico_id
''';

  /// Tablas que afectan a una orden: si cambia cualquiera, el Stream se
  /// vuelve a ejecutar.
  Set<ResultSetImplementation> get _tablasOrden => {
        db.ordenes,
        db.vehiculos,
        db.clientes,
        db.mecanicos,
        db.trabajos,
        db.ordenRepuestos,
        db.pagos,
      };

  OrdenResumen _mapOrden(QueryRow r) => OrdenResumen(
        id: r.read<int>('id'),
        fechaEntrada: r.read<DateTime>('fecha_entrada'),
        fechaEntrega: r.readNullable<DateTime>('fecha_entrega'),
        estado: EstadoOrden.values[r.read<int>('estado')],
        problema: r.read<String>('problema'),
        kilometrajeEntrada: r.read<int>('kilometraje_entrada'),
        vehiculoId: r.read<int>('vehiculo_id'),
        matricula: r.read<String>('matricula'),
        marca: r.read<String>('marca'),
        modelo: r.read<String>('modelo'),
        anio: r.read<int>('anio'),
        clienteId: r.read<int>('cliente_id'),
        clienteNombre: r.read<String>('cliente_nombre'),
        clienteTelefono: r.read<String>('cliente_telefono'),
        mecanicoId: r.read<int>('mecanico_id'),
        mecanicoNombre: r.read<String>('mecanico_nombre'),
        manoObra: r.read<double>('mano_obra'),
        totalRepuestos: r.read<double>('total_repuestos'),
        pagado: r.read<double>('pagado'),
      );

  // ===========================================================================
  // ÓRDENES
  // ===========================================================================

  /// Lista de órdenes con filtros opcionales.
  Stream<List<OrdenResumen>> watchOrdenes({
    Iterable<EstadoOrden>? estados,
    int? vehiculoId,
    int? clienteId,
    int? mecanicoId,
    String? busqueda,
  }) {
    final condiciones = <String>[];
    final variables = <Variable>[];

    if (estados != null && estados.isNotEmpty) {
      condiciones.add('o.estado IN (${estados.map((e) => e.index).join(',')})');
    }
    if (vehiculoId != null) {
      condiciones.add('o.vehiculo_id = ?');
      variables.add(Variable<int>(vehiculoId));
    }
    if (clienteId != null) {
      condiciones.add('v.cliente_id = ?');
      variables.add(Variable<int>(clienteId));
    }
    if (mecanicoId != null) {
      condiciones.add('o.mecanico_id = ?');
      variables.add(Variable<int>(mecanicoId));
    }
    final q = busqueda?.trim() ?? '';
    if (q.isNotEmpty) {
      condiciones.add(
          '(v.matricula LIKE ? OR c.nombre LIKE ? OR o.problema LIKE ?)');
      final patron = '%$q%';
      variables.addAll([
        Variable<String>(patron),
        Variable<String>(patron),
        Variable<String>(patron),
      ]);
    }

    final where =
        condiciones.isEmpty ? '' : 'WHERE ${condiciones.join(' AND ')}';
    final sql = '$_sqlOrden $where ORDER BY o.fecha_entrada DESC, o.id DESC';

    return db
        .customSelect(sql, variables: variables, readsFrom: _tablasOrden)
        .map(_mapOrden)
        .watch();
  }

  /// Órdenes abiertas (no entregadas ni canceladas).
  Stream<List<OrdenResumen>> watchOrdenesAbiertas() =>
      watchOrdenes(estados: EstadoOrdenX.abiertos);

  /// Una sola orden (para la pantalla de detalle).
  Stream<OrdenResumen?> watchOrden(int ordenId) => db
      .customSelect('$_sqlOrden WHERE o.id = ?',
          variables: [Variable<int>(ordenId)], readsFrom: _tablasOrden)
      .map(_mapOrden)
      .watchSingleOrNull();

  Future<Orden> _orden(int id) =>
      (db.select(db.ordenes)..where((o) => o.id.equals(id))).getSingle();

  Future<void> _exigirEditable(int ordenId) async {
    final o = await _orden(ordenId);
    if (!o.estado.editable) {
      throw ReglaNegocioException(
          'La orden #$ordenId está "${o.estado.etiqueta}" y ya no se puede modificar.');
    }
  }

  /// Registra la llegada de un vehículo. Actualiza su kilometraje.
  Future<int> crearOrden({
    required int vehiculoId,
    required int mecanicoId,
    required String problema,
    required int kilometraje,
    DateTime? fechaEntrada,
  }) {
    if (problema.trim().isEmpty) {
      throw const ReglaNegocioException('Describa el problema que reporta el cliente.');
    }
    if (kilometraje < 0) {
      throw const ReglaNegocioException('El kilometraje no puede ser negativo.');
    }
    return db.transaction(() async {
      final abiertas = await (db.select(db.ordenes)
            ..where((o) =>
                o.vehiculoId.equals(vehiculoId) &
                o.estado.isInValues(EstadoOrdenX.abiertos)))
          .get();
      if (abiertas.isNotEmpty) {
        throw ReglaNegocioException(
            'Este vehículo ya tiene la orden #${abiertas.first.id} abierta.');
      }
      final id = await db.into(db.ordenes).insert(OrdenesCompanion.insert(
            vehiculoId: vehiculoId,
            mecanicoId: mecanicoId,
            fechaEntrada: fechaEntrada ?? DateTime.now(),
            problema: problema.trim(),
            estado: EstadoOrden.recibida,
            kilometrajeEntrada: Value(kilometraje),
          ));
      await (db.update(db.vehiculos)..where((v) => v.id.equals(vehiculoId)))
          .write(VehiculosCompanion(kilometraje: Value(kilometraje)));
      return id;
    });
  }

  /// Cambia el mecánico asignado o el problema descrito.
  Future<void> actualizarOrden(int ordenId,
      {int? mecanicoId, String? problema}) async {
    await _exigirEditable(ordenId);
    await (db.update(db.ordenes)..where((o) => o.id.equals(ordenId))).write(
      OrdenesCompanion(
        mecanicoId: mecanicoId == null ? const Value.absent() : Value(mecanicoId),
        problema: problema == null ? const Value.absent() : Value(problema.trim()),
      ),
    );
  }

  /// Cambia el estado de la orden respetando las reglas.
  Future<void> cambiarEstado(int ordenId, EstadoOrden nuevo) async {
    await _exigirEditable(ordenId);
    if (nuevo == EstadoOrden.cancelada) {
      return cancelarOrden(ordenId);
    }
    await (db.update(db.ordenes)..where((o) => o.id.equals(ordenId))).write(
      OrdenesCompanion(
        estado: Value(nuevo),
        fechaEntrega:
            Value(nuevo == EstadoOrden.entregada ? DateTime.now() : null),
      ),
    );
  }

  /// Avanza al siguiente estado del flujo.
  Future<void> avanzarEstado(int ordenId) async {
    final o = await _orden(ordenId);
    final sig = o.estado.siguiente;
    if (sig == null) {
      throw const ReglaNegocioException('La orden ya terminó su flujo.');
    }
    await cambiarEstado(ordenId, sig);
  }

  /// Regresa al estado anterior (corrección de errores).
  Future<void> retrocederEstado(int ordenId) async {
    final o = await _orden(ordenId);
    final ant = o.estado.anterior;
    if (ant == null) {
      throw const ReglaNegocioException('No hay un estado anterior al que volver.');
    }
    await cambiarEstado(ordenId, ant);
  }

  /// Cancela la orden. Los repuestos usados vuelven al inventario.
  /// Decisión: no se cancela una orden que ya tiene pagos (habría que
  /// devolver dinero); primero se eliminan los pagos.
  Future<void> cancelarOrden(int ordenId) => db.transaction(() async {
        await _exigirEditable(ordenId);
        final pagos = await (db.select(db.pagos)
              ..where((p) => p.ordenId.equals(ordenId)))
            .get();
        if (pagos.isNotEmpty) {
          throw const ReglaNegocioException(
              'La orden tiene pagos registrados. Elimínelos antes de cancelarla.');
        }
        final usados = await (db.select(db.ordenRepuestos)
              ..where((r) => r.ordenId.equals(ordenId)))
            .get();
        for (final u in usados) {
          await _sumarExistencias(u.repuestoId, u.cantidad);
        }
        await (db.update(db.ordenes)..where((o) => o.id.equals(ordenId)))
            .write(const OrdenesCompanion(estado: Value(EstadoOrden.cancelada)));
      });

  // ---------------------------------------------------------------------------
  // Trabajos (mano de obra)
  // ---------------------------------------------------------------------------
  Stream<List<Trabajo>> watchTrabajos(int ordenId) => (db.select(db.trabajos)
        ..where((t) => t.ordenId.equals(ordenId))
        ..orderBy([(t) => OrderingTerm.asc(t.id)]))
      .watch();

  Future<void> agregarTrabajo(int ordenId, String descripcion, double precio) async {
    if (descripcion.trim().isEmpty) {
      throw const ReglaNegocioException('Escriba la descripción del trabajo.');
    }
    if (precio < 0) {
      throw const ReglaNegocioException('El precio no puede ser negativo.');
    }
    await _exigirEditable(ordenId);
    await db.into(db.trabajos).insert(TrabajosCompanion.insert(
        ordenId: ordenId, descripcion: descripcion.trim(), precio: precio));
  }

  Future<void> eliminarTrabajo(Trabajo t) async {
    await _exigirEditable(t.ordenId);
    await (db.delete(db.trabajos)..where((x) => x.id.equals(t.id))).go();
  }

  // ---------------------------------------------------------------------------
  // Repuestos usados en la orden (descuentan inventario)
  // ---------------------------------------------------------------------------
  Stream<List<RepuestoUsadoDetalle>> watchRepuestosDeOrden(int ordenId) => db
      .customSelect(
        '''
SELECT u.id, u.repuesto_id, u.cantidad, u.precio_unitario, r.codigo, r.nombre
  FROM orden_repuestos u JOIN repuestos r ON r.id = u.repuesto_id
 WHERE u.orden_id = ? ORDER BY u.id''',
        variables: [Variable<int>(ordenId)],
        readsFrom: {db.ordenRepuestos, db.repuestos},
      )
      .map((r) => RepuestoUsadoDetalle(
            id: r.read<int>('id'),
            repuestoId: r.read<int>('repuesto_id'),
            codigo: r.read<String>('codigo'),
            nombre: r.read<String>('nombre'),
            cantidad: r.read<int>('cantidad'),
            precioUnitario: r.read<double>('precio_unitario'),
          ))
      .watch();

  /// Usa [cantidad] unidades de un repuesto en la orden: valida existencias,
  /// guarda la línea con el precio actual y descuenta el inventario, todo en
  /// una transacción (o se hace todo o no se hace nada).
  Future<ResultadoUsoRepuesto> usarRepuesto(
      int ordenId, int repuestoId, int cantidad) {
    if (cantidad <= 0) {
      throw const ReglaNegocioException('La cantidad debe ser mayor que cero.');
    }
    return db.transaction(() async {
      await _exigirEditable(ordenId);
      final rep = await (db.select(db.repuestos)
            ..where((r) => r.id.equals(repuestoId)))
          .getSingle();
      if (rep.existencias < cantidad) {
        throw ReglaNegocioException(
            'Solo hay ${rep.existencias} unidad(es) de "${rep.nombre}".');
      }
      await db.into(db.ordenRepuestos).insert(OrdenRepuestosCompanion.insert(
            ordenId: ordenId,
            repuestoId: repuestoId,
            cantidad: cantidad,
            precioUnitario: rep.precioVenta,
          ));
      await _sumarExistencias(repuestoId, -cantidad);
      return ResultadoUsoRepuesto(
          rep.copyWith(existencias: rep.existencias - cantidad));
    });
  }

  /// Quita una línea de repuesto de la orden y devuelve las unidades.
  Future<void> devolverRepuesto(RepuestoUsadoDetalle linea, int ordenId) =>
      db.transaction(() async {
        await _exigirEditable(ordenId);
        await _sumarExistencias(linea.repuestoId, linea.cantidad);
        await (db.delete(db.ordenRepuestos)..where((x) => x.id.equals(linea.id)))
            .go();
      });

  Future<void> _sumarExistencias(int repuestoId, int delta) => db.customUpdate(
        'UPDATE repuestos SET existencias = existencias + ? WHERE id = ?',
        variables: [Variable<int>(delta), Variable<int>(repuestoId)],
        updates: {db.repuestos},
        updateKind: UpdateKind.update,
      );

  // ---------------------------------------------------------------------------
  // Pagos (se admite pagar en varias partes)
  // ---------------------------------------------------------------------------
  Stream<List<Pago>> watchPagos(int ordenId) => (db.select(db.pagos)
        ..where((p) => p.ordenId.equals(ordenId))
        ..orderBy([(p) => OrderingTerm.asc(p.fecha)]))
      .watch();

  Future<void> registrarPago(int ordenId, double monto,
      {String metodo = 'Efectivo'}) async {
    if (monto <= 0) {
      throw const ReglaNegocioException('El monto debe ser mayor que cero.');
    }
    final orden = await watchOrden(ordenId).first;
    if (orden == null) throw const ReglaNegocioException('La orden no existe.');
    if (orden.estado == EstadoOrden.cancelada) {
      throw const ReglaNegocioException('No se puede cobrar una orden cancelada.');
    }
    if (monto > orden.saldo + 0.009) {
      throw ReglaNegocioException(
          'El monto supera el saldo pendiente (${orden.saldo.toStringAsFixed(2)}).');
    }
    await db.into(db.pagos).insert(PagosCompanion.insert(
          ordenId: ordenId,
          monto: monto,
          fecha: DateTime.now(),
          metodo: Value(metodo),
        ));
  }

  Future<void> eliminarPago(Pago p) =>
      (db.delete(db.pagos)..where((x) => x.id.equals(p.id))).go();

  // ===========================================================================
  // CLIENTES Y VEHÍCULOS
  // ===========================================================================

  Stream<List<ClienteResumen>> watchClientes({String? busqueda}) {
    final q = busqueda?.trim() ?? '';
    final variables = <Variable>[];
    var where = '';
    if (q.isNotEmpty) {
      where = '''WHERE c.nombre LIKE ? OR c.telefono LIKE ?
        OR EXISTS (SELECT 1 FROM vehiculos vv
                   WHERE vv.cliente_id = c.id AND vv.matricula LIKE ?)''';
      variables.addAll([
        Variable<String>('%$q%'),
        Variable<String>('%$q%'),
        Variable<String>('%$q%'),
      ]);
    }
    return db
        .customSelect(
          '''
SELECT c.*,
  (SELECT COUNT(*) FROM vehiculos v WHERE v.cliente_id = c.id) AS n_vehiculos,
  (SELECT COALESCE(SUM(
      (SELECT COALESCE(SUM(t.precio), 0.0) FROM trabajos t WHERE t.orden_id = o.id)
    + (SELECT COALESCE(SUM(r.cantidad * r.precio_unitario), 0.0)
         FROM orden_repuestos r WHERE r.orden_id = o.id)
    - (SELECT COALESCE(SUM(p.monto), 0.0) FROM pagos p WHERE p.orden_id = o.id)
   ), 0.0)
     FROM ordenes o JOIN vehiculos v2 ON v2.id = o.vehiculo_id
    WHERE v2.cliente_id = c.id AND o.estado IN (3, 4)) AS saldo
FROM clientes c $where
ORDER BY c.nombre COLLATE NOCASE''',
          variables: variables,
          readsFrom: _tablasOrden,
        )
        .map((r) => ClienteResumen(
              db.clientes.map(r.data),
              r.read<int>('n_vehiculos'),
              r.read<double>('saldo'),
            ))
        .watch();
  }

  Stream<Cliente?> watchCliente(int id) =>
      (db.select(db.clientes)..where((c) => c.id.equals(id)))
          .watchSingleOrNull();

  Future<int> crearCliente(
      {required String nombre, required String telefono, String? direccion}) {
    _validarCliente(nombre, telefono);
    return db.into(db.clientes).insert(ClientesCompanion.insert(
          nombre: nombre.trim(),
          telefono: telefono.trim(),
          direccion: Value(_nulo(direccion)),
        ));
  }

  Future<void> actualizarCliente(int id,
      {required String nombre, required String telefono, String? direccion}) async {
    _validarCliente(nombre, telefono);
    await (db.update(db.clientes)..where((c) => c.id.equals(id))).write(
      ClientesCompanion(
        nombre: Value(nombre.trim()),
        telefono: Value(telefono.trim()),
        direccion: Value(_nulo(direccion)),
      ),
    );
  }

  /// Solo se elimina un cliente sin vehículos (para no perder historial).
  Future<void> eliminarCliente(int id) async {
    final n = await (db.select(db.vehiculos)
          ..where((v) => v.clienteId.equals(id)))
        .get();
    if (n.isNotEmpty) {
      throw const ReglaNegocioException(
          'El cliente tiene vehículos registrados; no se puede eliminar.');
    }
    await (db.delete(db.clientes)..where((c) => c.id.equals(id))).go();
  }

  void _validarCliente(String nombre, String telefono) {
    if (nombre.trim().isEmpty) {
      throw const ReglaNegocioException('El nombre es obligatorio.');
    }
    if (!RegExp(r'^[0-9+\-\s]{6,20}$').hasMatch(telefono.trim())) {
      throw const ReglaNegocioException('Teléfono inválido (solo dígitos, mínimo 6).');
    }
  }

  String? _nulo(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  Stream<List<Vehiculo>> watchVehiculosDeCliente(int clienteId) =>
      (db.select(db.vehiculos)
            ..where((v) => v.clienteId.equals(clienteId))
            ..orderBy([(v) => OrderingTerm.asc(v.matricula)]))
          .watch();

  Stream<Vehiculo?> watchVehiculo(int id) =>
      (db.select(db.vehiculos)..where((v) => v.id.equals(id)))
          .watchSingleOrNull();

  /// Búsqueda de vehículos por matrícula, marca, modelo o dueño (JOIN tipado).
  Stream<List<VehiculoConCliente>> watchVehiculos({String? busqueda}) {
    final q = '%${busqueda?.trim() ?? ''}%';
    final consulta = db.select(db.vehiculos).join([
      innerJoin(db.clientes, db.clientes.id.equalsExp(db.vehiculos.clienteId)),
    ])
      ..where(db.vehiculos.matricula.like(q) |
          db.vehiculos.marca.like(q) |
          db.vehiculos.modelo.like(q) |
          db.clientes.nombre.like(q))
      ..orderBy([OrderingTerm.asc(db.vehiculos.matricula)]);
    return consulta.watch().map((filas) => filas
        .map((f) => VehiculoConCliente(
            f.readTable(db.vehiculos), f.readTable(db.clientes).nombre))
        .toList());
  }

  Future<int> crearVehiculo({
    required int clienteId,
    required String matricula,
    required String marca,
    required String modelo,
    required int anio,
    required int kilometraje,
  }) async {
    final mat = _validarVehiculo(matricula, marca, modelo, anio, kilometraje);
    final existe = await (db.select(db.vehiculos)
          ..where((v) => v.matricula.equals(mat)))
        .getSingleOrNull();
    if (existe != null) {
      throw ReglaNegocioException('Ya existe un vehículo con matrícula $mat.');
    }
    return db.into(db.vehiculos).insert(VehiculosCompanion.insert(
          clienteId: clienteId,
          matricula: mat,
          marca: marca.trim(),
          modelo: modelo.trim(),
          anio: anio,
          kilometraje: Value(kilometraje),
        ));
  }

  Future<void> actualizarVehiculo(int id,
      {required String matricula,
      required String marca,
      required String modelo,
      required int anio,
      required int kilometraje}) async {
    final mat = _validarVehiculo(matricula, marca, modelo, anio, kilometraje);
    final existe = await (db.select(db.vehiculos)
          ..where((v) => v.matricula.equals(mat) & v.id.equals(id).not()))
        .getSingleOrNull();
    if (existe != null) {
      throw ReglaNegocioException('Ya existe otro vehículo con matrícula $mat.');
    }
    await (db.update(db.vehiculos)..where((v) => v.id.equals(id))).write(
      VehiculosCompanion(
        matricula: Value(mat),
        marca: Value(marca.trim()),
        modelo: Value(modelo.trim()),
        anio: Value(anio),
        kilometraje: Value(kilometraje),
      ),
    );
  }

  /// Solo se elimina un vehículo que nunca ha tenido órdenes.
  Future<void> eliminarVehiculo(int id) async {
    final ords = await (db.select(db.ordenes)
          ..where((o) => o.vehiculoId.equals(id)))
        .get();
    if (ords.isNotEmpty) {
      throw const ReglaNegocioException(
          'El vehículo tiene historial de servicios; no se puede eliminar.');
    }
    await (db.delete(db.vehiculos)..where((v) => v.id.equals(id))).go();
  }

  String _validarVehiculo(
      String matricula, String marca, String modelo, int anio, int km) {
    final mat = matricula.trim().toUpperCase();
    if (mat.isEmpty) throw const ReglaNegocioException('La matrícula es obligatoria.');
    if (marca.trim().isEmpty || modelo.trim().isEmpty) {
      throw const ReglaNegocioException('Marca y modelo son obligatorios.');
    }
    final maxAnio = DateTime.now().year + 1;
    if (anio < 1900 || anio > maxAnio) {
      throw ReglaNegocioException('El año debe estar entre 1900 y $maxAnio.');
    }
    if (km < 0) throw const ReglaNegocioException('Kilometraje inválido.');
    return mat;
  }

  // ===========================================================================
  // MECÁNICOS
  // ===========================================================================
  Stream<List<Mecanico>> watchMecanicos({bool soloActivos = false}) {
    final q = db.select(db.mecanicos)
      ..orderBy([(m) => OrderingTerm.asc(m.nombre)]);
    if (soloActivos) q.where((m) => m.activo.equals(true));
    return q.watch();
  }

  Future<void> guardarMecanico({int? id, required String nombre, bool activo = true}) async {
    if (nombre.trim().isEmpty) {
      throw const ReglaNegocioException('El nombre es obligatorio.');
    }
    if (id == null) {
      await db.into(db.mecanicos).insert(MecanicosCompanion.insert(
          nombre: nombre.trim(), activo: Value(activo)));
    } else {
      await (db.update(db.mecanicos)..where((m) => m.id.equals(id))).write(
          MecanicosCompanion(nombre: Value(nombre.trim()), activo: Value(activo)));
    }
  }

  /// Carga de trabajo: órdenes abiertas por mecánico, desglosadas por estado.
  Stream<List<CargaMecanico>> watchCargaMecanicos() => db
      .customSelect(
        '''
SELECT m.*,
  COALESCE(SUM(CASE WHEN o.estado IN (0, 1, 2, 3) THEN 1 ELSE 0 END), 0) AS abiertas,
  COALESCE(SUM(CASE WHEN o.estado IN (0, 1) THEN 1 ELSE 0 END), 0) AS diag,
  COALESCE(SUM(CASE WHEN o.estado = 2 THEN 1 ELSE 0 END), 0) AS repar,
  COALESCE(SUM(CASE WHEN o.estado = 3 THEN 1 ELSE 0 END), 0) AS listas
FROM mecanicos m LEFT JOIN ordenes o ON o.mecanico_id = m.id
GROUP BY m.id
ORDER BY abiertas DESC, m.nombre''',
        readsFrom: {db.mecanicos, db.ordenes},
      )
      .map((r) => CargaMecanico(
            mecanico: db.mecanicos.map(r.data),
            abiertas: r.read<int>('abiertas'),
            enDiagnostico: r.read<int>('diag'),
            enReparacion: r.read<int>('repar'),
            listas: r.read<int>('listas'),
          ))
      .watch();

  // ===========================================================================
  // INVENTARIO
  // ===========================================================================
  Stream<List<Repuesto>> watchRepuestos({String? busqueda, bool soloBajos = false}) {
    final q = db.select(db.repuestos)
      ..orderBy([(r) => OrderingTerm.asc(r.nombre)]);
    final texto = busqueda?.trim() ?? '';
    if (texto.isNotEmpty) {
      q.where((r) => r.nombre.like('%$texto%') | r.codigo.like('%$texto%'));
    }
    if (soloBajos) {
      q.where((r) => r.existencias.isSmallerOrEqual(r.stockMinimo));
    }
    return q.watch();
  }

  /// Repuestos por agotarse (existencias <= mínimo).
  Stream<List<Repuesto>> watchRepuestosBajos() => watchRepuestos(soloBajos: true);

  Future<void> guardarRepuesto({
    int? id,
    required String codigo,
    required String nombre,
    required double precioVenta,
    required int existencias,
    required int stockMinimo,
  }) async {
    final cod = codigo.trim().toUpperCase();
    if (cod.isEmpty || nombre.trim().isEmpty) {
      throw const ReglaNegocioException('Código y nombre son obligatorios.');
    }
    if (precioVenta < 0 || existencias < 0 || stockMinimo < 0) {
      throw const ReglaNegocioException('Los valores no pueden ser negativos.');
    }
    final dup = await (db.select(db.repuestos)
          ..where((r) => r.codigo.equals(cod) & (id == null
              ? const Constant(true)
              : r.id.equals(id).not())))
        .getSingleOrNull();
    if (dup != null) {
      throw ReglaNegocioException('Ya existe un repuesto con el código $cod.');
    }
    final datos = RepuestosCompanion(
      codigo: Value(cod),
      nombre: Value(nombre.trim()),
      precioVenta: Value(precioVenta),
      existencias: Value(existencias),
      stockMinimo: Value(stockMinimo),
    );
    if (id == null) {
      await db.into(db.repuestos).insert(datos);
    } else {
      await (db.update(db.repuestos)..where((r) => r.id.equals(id))).write(datos);
    }
  }

  /// Entrada de mercancía: suma unidades compradas.
  Future<void> reabastecer(int repuestoId, int cantidad) {
    if (cantidad <= 0) {
      throw const ReglaNegocioException('La cantidad debe ser mayor que cero.');
    }
    return _sumarExistencias(repuestoId, cantidad);
  }

  // ===========================================================================
  // REPORTES
  // ===========================================================================

  /// Cantidad de órdenes por estado (para el tablero).
  Stream<Map<EstadoOrden, int>> watchConteoPorEstado() => db
      .customSelect(
        'SELECT estado, COUNT(*) AS n FROM ordenes GROUP BY estado',
        readsFrom: {db.ordenes},
      )
      .watch()
      .map((filas) {
        final mapa = {for (final e in EstadoOrden.values) e: 0};
        for (final f in filas) {
          mapa[EstadoOrden.values[f.read<int>('estado')]] = f.read<int>('n');
        }
        return mapa;
      });

  /// Clientes con saldo pendiente. Decisión: se cuenta la deuda de las
  /// órdenes terminadas (lista para entregar o entregada); en las órdenes en
  /// proceso el total todavía puede cambiar.
  Stream<List<Deudor>> watchDeudores() => db
      .customSelect(
        '''
SELECT c.id, c.nombre, c.telefono, COUNT(*) AS n, SUM(x.total - x.pagado) AS saldo
FROM (
  SELECT v.cliente_id AS cliente_id,
    (SELECT COALESCE(SUM(t.precio), 0.0) FROM trabajos t WHERE t.orden_id = o.id)
    + (SELECT COALESCE(SUM(r.cantidad * r.precio_unitario), 0.0)
         FROM orden_repuestos r WHERE r.orden_id = o.id) AS total,
    (SELECT COALESCE(SUM(p.monto), 0.0) FROM pagos p WHERE p.orden_id = o.id) AS pagado
  FROM ordenes o JOIN vehiculos v ON v.id = o.vehiculo_id
  WHERE o.estado IN (3, 4)
) x
JOIN clientes c ON c.id = x.cliente_id
WHERE x.total - x.pagado > 0.009
GROUP BY c.id
ORDER BY saldo DESC''',
        readsFrom: _tablasOrden,
      )
      .map((r) => Deudor(
            clienteId: r.read<int>('id'),
            nombre: r.read<String>('nombre'),
            telefono: r.read<String>('telefono'),
            ordenesConSaldo: r.read<int>('n'),
            saldo: r.read<double>('saldo'),
          ))
      .watch();

  /// Facturación de un período: órdenes ENTREGADAS entre [desde] y [hasta]
  /// (ambos días incluidos) y dinero cobrado en ese período.
  Stream<ReporteFacturacion> watchFacturacion(DateTime desde, DateTime hasta) {
    final ini = DateTime(desde.year, desde.month, desde.day);
    // Día siguiente por calendario (no sumando 24 h: con cambio de horario un
    // día puede durar 23 o 25 h).
    final fin = DateTime(hasta.year, hasta.month, hasta.day + 1);
    final ordenes = db
        .customSelect(
          '$_sqlOrden WHERE o.estado = 4 AND o.fecha_entrega >= ? AND o.fecha_entrega < ? '
          'ORDER BY o.fecha_entrega DESC',
          variables: [Variable<DateTime>(ini), Variable<DateTime>(fin)],
          readsFrom: _tablasOrden,
        )
        .map(_mapOrden)
        .watch();
    // asyncMap: por cada nueva lista de órdenes se consulta lo cobrado.
    return ordenes.asyncMap((lista) async {
      final fila = await db.customSelect(
        'SELECT COALESCE(SUM(p.monto), 0.0) AS cobrado FROM pagos p '
        'JOIN ordenes o ON o.id = p.orden_id '
        'WHERE o.estado != 5 AND p.fecha >= ? AND p.fecha < ?',
        variables: [Variable<DateTime>(ini), Variable<DateTime>(fin)],
      ).getSingle();
      return ReporteFacturacion(
        desde: ini,
        hasta: DateTime(hasta.year, hasta.month, hasta.day),
        ordenes: lista,
        cobrado: fila.read<double>('cobrado'),
      );
    });
  }

  // ===========================================================================
  // DATOS DE DEMOSTRACIÓN (para probar la app y tomar capturas)
  // ===========================================================================
  Future<void> cargarDatosDemo() async {
    final hay = await db.select(db.clientes).get();
    if (hay.isNotEmpty) {
      throw const ReglaNegocioException('Ya hay clientes registrados.');
    }
    final mecs = await db.select(db.mecanicos).get();
    final reps = await db.select(db.repuestos).get();
    if (mecs.isEmpty || reps.length < 3) {
      throw const ReglaNegocioException('Faltan mecánicos o repuestos base.');
    }
    final hoy = DateTime.now();

    final c1 = await crearCliente(
        nombre: 'María González', telefono: '53 5123 4567', direccion: 'Calle Martí #45');
    final c2 = await crearCliente(nombre: 'José Hernández', telefono: '53 5876 5432');
    final c3 = await crearCliente(
        nombre: 'Ana Rodríguez', telefono: '48 77 1234', direccion: 'Rpto. Hermanos Cruz');

    final v1 = await crearVehiculo(
        clienteId: c1, matricula: 'P123456', marca: 'Lada', modelo: '2107', anio: 1988, kilometraje: 150000);
    final v2 = await crearVehiculo(
        clienteId: c1, matricula: 'P654321', marca: 'Kia', modelo: 'Picanto', anio: 2015, kilometraje: 82000);
    final v3 = await crearVehiculo(
        clienteId: c2, matricula: 'B234567', marca: 'Moskvitch', modelo: '412', anio: 1982, kilometraje: 210000);
    final v4 = await crearVehiculo(
        clienteId: c3, matricula: 'P777888', marca: 'Geely', modelo: 'CK', anio: 2010, kilometraje: 120500);

    // Orden entregada y pagada a medias (genera deuda)
    final o1 = await crearOrden(
        vehiculoId: v1, mecanicoId: mecs[0].id, problema: 'Ruido en el motor y pérdida de aceite',
        kilometraje: 150300, fechaEntrada: hoy.subtract(const Duration(days: 6)));
    await agregarTrabajo(o1, 'Cambio de aceite', 800);
    await agregarTrabajo(o1, 'Cambio de junta de tapa de válvulas', 1500);
    await usarRepuesto(o1, reps[0].id, 4);
    await usarRepuesto(o1, reps[1].id, 1);
    for (var i = 0; i < 4; i++) {
      await avanzarEstado(o1);
    }
    await registrarPago(o1, 3000, metodo: 'Efectivo');

    // Orden entregada y pagada completa
    final o2 = await crearOrden(
        vehiculoId: v4, mecanicoId: mecs[1 % mecs.length].id,
        problema: 'Frenos chillan al frenar', kilometraje: 121000,
        fechaEntrada: hoy.subtract(const Duration(days: 3)));
    await agregarTrabajo(o2, 'Cambio de pastillas delanteras', 1200);
    await usarRepuesto(o2, reps[2].id, 1);
    for (var i = 0; i < 4; i++) {
      await avanzarEstado(o2);
    }
    final total2 = (await watchOrden(o2).first)!.saldo;
    await registrarPago(o2, total2, metodo: 'Transferencia');

    // Órdenes abiertas en distintos estados
    final o3 = await crearOrden(
        vehiculoId: v2, mecanicoId: mecs[0].id, problema: 'Alineación y balanceo',
        kilometraje: 82500, fechaEntrada: hoy.subtract(const Duration(days: 1)));
    await avanzarEstado(o3);
    await avanzarEstado(o3);
    await agregarTrabajo(o3, 'Alineación', 600);

    await crearOrden(
        vehiculoId: v3, mecanicoId: mecs[1 % mecs.length].id,
        problema: 'No arranca en frío', kilometraje: 210400, fechaEntrada: hoy);
  }
}
