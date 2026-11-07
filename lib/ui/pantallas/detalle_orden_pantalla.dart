// =============================================================================
// detalle_orden_pantalla.dart
// Detalle de una orden de servicio. De arriba abajo:
//   1. Cabecera: estado, vehículo, cliente, mecánico, kilometraje, problema.
//   2. Línea de tiempo vertical del flujo de estados.
//   3. Tarjetas expandibles (ExpansionTile): Trabajos, Repuestos y Pagos,
//      con sus botones para agregar/eliminar (solo si la orden es editable).
//   4. "Ticket" de totales tipo recibo.
//   5. Botón principal grande abajo con la SIGUIENTE acción del flujo
//      ("Pasar a diagnóstico", "Marcar lista para entregar", "Entregar al
//      cliente"). El menú del AppBar ofrece retroceder, cambiar mecánico,
//      editar el problema y cancelar.
// Todo se alimenta de Streams: al agregar un trabajo o un pago, el ticket y
// el saldo se recalculan solos.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import '../widgets/dialogos.dart';
import '../widgets/dialogos_orden.dart';
import '../widgets/estados_vista.dart';
import '../widgets/linea_tiempo_estados.dart';
import '../widgets/mensajes.dart';
import '../widgets/pildora_estado.dart';
import '../widgets/tarjeta.dart';
import '../widgets/ticket_totales.dart';
import 'detalle_cliente_pantalla.dart';
import 'vehiculo_pantalla.dart';

class DetalleOrdenPantalla extends StatefulWidget {
  final int ordenId;
  const DetalleOrdenPantalla({super.key, required this.ordenId});

  @override
  State<DetalleOrdenPantalla> createState() => _DetalleOrdenPantallaState();
}

/// Opciones del menú del AppBar.
enum _Opcion { anterior, mecanico, problema, cliente, vehiculo, cancelar }

class _DetalleOrdenPantallaState extends State<DetalleOrdenPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  int get _id => widget.ordenId;

  // Un Stream por cada parte de la orden, creados una sola vez.
  late final Stream<OrdenResumen?> _orden = repo.watchOrden(_id);
  late final Stream<List<Trabajo>> _trabajos = repo.watchTrabajos(_id);
  late final Stream<List<RepuestoUsadoDetalle>> _repuestos =
      repo.watchRepuestosDeOrden(_id);
  late final Stream<List<Pago>> _pagos = repo.watchPagos(_id);

  bool _ocupado = false;

  // ===========================================================================
  // Acciones de estado
  // ===========================================================================

  Future<void> _avanzar(OrdenResumen o) async {
    final sig = o.estado.siguiente;
    if (sig == null) return;
    // Confirmaciones amables en los pasos delicados.
    if (sig == EstadoOrden.lista && o.total <= 0) {
      final ok = await confirmar(context,
          titulo: 'Orden sin cargos',
          mensaje: 'No se han registrado trabajos ni repuestos. '
              '¿Marcarla lista para entregar de todos modos?');
      if (!ok) return;
    }
    if (sig == EstadoOrden.entregada && o.saldo > 0.009) {
      if (!mounted) return;
      final ok = await confirmar(context,
          titulo: 'Entregar con saldo pendiente',
          mensaje: 'El cliente aún debe ${dinero(o.saldo)}. Quedará como '
              'deuda. ¿Entregar el vehículo?',
          textoConfirmar: 'Entregar');
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _ocupado = true);
    await ejecutarAccion(context, () => repo.avanzarEstado(_id),
        exito: 'Orden #$_id: ${sig.etiqueta}');
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _elegirOpcion(_Opcion op, OrdenResumen o) async {
    switch (op) {
      case _Opcion.anterior:
        await ejecutarAccion(context, () => repo.retrocederEstado(_id),
            exito: 'Orden devuelta a "${o.estado.anterior?.etiqueta}"');
      case _Opcion.mecanico:
        await _cambiarMecanico(o);
      case _Opcion.problema:
        await abrirDialogo(
          context,
          DialogoTexto(
            titulo: 'Editar problema',
            etiqueta: 'Problema reportado',
            icono: Icons.report_problem_outlined,
            inicial: o.problema,
            lineas: 5,
            guardar: (t) => repo.actualizarOrden(_id, problema: t),
          ),
        );
      case _Opcion.cliente:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DetalleClientePantalla(clienteId: o.clienteId)));
      case _Opcion.vehiculo:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VehiculoPantalla(vehiculoId: o.vehiculoId)));
      case _Opcion.cancelar:
        final ok = await confirmar(context,
            titulo: 'Cancelar la orden #$_id',
            mensaje: 'Los repuestos usados volverán al inventario. '
                'Esta acción no se puede deshacer.',
            textoConfirmar: 'Cancelar orden',
            peligroso: true);
        if (!ok || !mounted) return;
        await ejecutarAccion(context, () => repo.cancelarOrden(_id),
            exito: 'Orden cancelada');
    }
  }

  /// Diálogo sencillo (SimpleDialog) con los mecánicos activos.
  Future<void> _cambiarMecanico(OrdenResumen o) async {
    final mecanicos = await repo.watchMecanicos(soloActivos: true).first;
    if (!mounted) return;
    final elegido = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Cambiar mecánico'),
        children: [
          for (final m in mecanicos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m.id),
              child: Row(
                children: [
                  Icon(m.id == o.mecanicoId
                      ? Icons.check_circle
                      : Icons.engineering_outlined,
                      color: Paleta.primario),
                  const SizedBox(width: 12),
                  Flexible(child: Text(m.nombre)), // nombres largos
                ],
              ),
            ),
        ],
      ),
    );
    if (elegido == null || elegido == o.mecanicoId || !mounted) return;
    await ejecutarAccion(
        context, () => repo.actualizarOrden(_id, mecanicoId: elegido),
        exito: 'Mecánico cambiado');
  }

  // ===========================================================================
  // Trabajos, repuestos y pagos
  // ===========================================================================

  Future<void> _agregarTrabajo() async {
    final ok = await abrirDialogo(
        context,
        DialogoTrabajo(
            guardar: (d, p) => repo.agregarTrabajo(_id, d, p)));
    if (ok && mounted) mostrarExito(context, 'Trabajo agregado');
  }

  Future<void> _eliminarTrabajo(Trabajo t) async {
    final ok = await confirmar(context,
        titulo: 'Eliminar trabajo',
        mensaje: '¿Quitar "${t.descripcion}" (${dinero(t.precio)})?',
        textoConfirmar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    await ejecutarAccion(context, () => repo.eliminarTrabajo(t),
        exito: 'Trabajo eliminado');
  }

  Future<void> _usarRepuesto() async {
    // El resultado se guarda desde dentro del diálogo para saber después si
    // el repuesto quedó por agotarse.
    ResultadoUsoRepuesto? resultado;
    final ok = await abrirDialogo(
      context,
      DialogoUsarRepuesto(
        guardar: (r, cantidad) async {
          resultado = await repo.usarRepuesto(_id, r.id, cantidad);
        },
      ),
    );
    final res = resultado;
    if (!ok || res == null || !mounted) return;
    if (res.quedoBajo) {
      await mostrarAvisoStock(context, res.repuesto); // aviso visible ámbar
    } else {
      mostrarExito(context, 'Repuesto agregado a la orden');
    }
  }

  Future<void> _devolverRepuesto(RepuestoUsadoDetalle l) async {
    final ok = await confirmar(context,
        titulo: 'Quitar repuesto',
        mensaje: 'Las ${l.cantidad} unidad(es) de "${l.nombre}" volverán '
            'al inventario.',
        textoConfirmar: 'Quitar',
        peligroso: true);
    if (!ok || !mounted) return;
    await ejecutarAccion(context, () => repo.devolverRepuesto(l, _id),
        exito: 'Repuesto devuelto al inventario');
  }

  Future<void> _registrarPago(OrdenResumen o) async {
    final ok = await abrirDialogo(
      context,
      DialogoPago(
        saldo: o.saldo,
        guardar: (monto, metodo) =>
            repo.registrarPago(_id, monto, metodo: metodo),
      ),
    );
    if (ok && mounted) mostrarExito(context, 'Pago registrado');
  }

  Future<void> _eliminarPago(Pago p) async {
    final ok = await confirmar(context,
        titulo: 'Eliminar pago',
        mensaje: '¿Eliminar el pago de ${dinero(p.monto)} del '
            '${fechaHora(p.fecha)}?',
        textoConfirmar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    await ejecutarAccion(context, () => repo.eliminarPago(p),
        exito: 'Pago eliminado');
  }

  // ===========================================================================
  // Interfaz
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OrdenResumen?>(
      stream: _orden,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return Scaffold(
              appBar: AppBar(title: Text('Orden #$_id')),
              body: const Cargando());
        }
        final o = snap.data;
        if (o == null) {
          return Scaffold(
            appBar: AppBar(title: Text('Orden #$_id')),
            body: const MensajeVacio(
                icono: Icons.search_off, titulo: 'La orden no existe'),
          );
        }
        return _pantalla(o);
      },
    );
  }

  Widget _pantalla(OrdenResumen o) {
    final editable = o.estado.editable;
    final textoAccion = o.estado.textoSiguienteAccion;
    return Scaffold(
      appBar: AppBar(
        title: Text('Orden #${o.id}'),
        actions: [
          PopupMenuButton<_Opcion>(
            tooltip: 'Más acciones',
            onSelected: (op) => _elegirOpcion(op, o),
            itemBuilder: (_) => [
              if (o.estado.anterior != null)
                PopupMenuItem(
                  value: _Opcion.anterior,
                  child: ListTile(
                    leading: const Icon(Icons.undo),
                    title: Text('Volver a "${o.estado.anterior!.etiqueta}"'),
                  ),
                ),
              if (editable)
                const PopupMenuItem(
                  value: _Opcion.mecanico,
                  child: ListTile(
                      leading: Icon(Icons.engineering_outlined),
                      title: Text('Cambiar mecánico')),
                ),
              if (editable)
                const PopupMenuItem(
                  value: _Opcion.problema,
                  child: ListTile(
                      leading: Icon(Icons.edit_note),
                      title: Text('Editar problema')),
                ),
              const PopupMenuItem(
                value: _Opcion.cliente,
                child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('Ver cliente')),
              ),
              const PopupMenuItem(
                value: _Opcion.vehiculo,
                child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Historial del vehículo')),
              ),
              if (o.estado.abierta)
                const PopupMenuItem(
                  value: _Opcion.cancelar,
                  child: ListTile(
                    leading: Icon(Icons.block, color: Paleta.error),
                    title: Text('Cancelar orden',
                        style: TextStyle(color: Paleta.error)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _cabecera(o),
          Tarjeta(
            child: LineaTiempoEstados(
              estado: o.estado,
              fechaEntrada: o.fechaEntrada,
              fechaEntrega: o.fechaEntrega,
            ),
          ),
          _seccionTrabajos(editable),
          _seccionRepuestos(editable),
          _seccionPagos(o),
          TicketTotales(o),
        ],
      ),
      // Botón principal con la siguiente acción del flujo.
      bottomNavigationBar: textoAccion == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    style: o.estado == EstadoOrden.lista
                        ? FilledButton.styleFrom(
                            backgroundColor: Paleta.acento)
                        : null,
                    onPressed: _ocupado ? null : () => _avanzar(o),
                    icon: Icon(o.estado.siguiente?.icono ?? Icons.arrow_forward),
                    label: Text(textoAccion),
                  ),
                ),
              ),
            ),
    );
  }

  /// Datos generales de la orden.
  Widget _cabecera(OrdenResumen o) {
    Widget dato(IconData icono, String texto, {VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, size: 18, color: Paleta.textoSecundario),
                const SizedBox(width: 10),
                Expanded(child: Text(texto)),
                if (onTap != null)
                  const Icon(Icons.chevron_right,
                      size: 18, color: Paleta.textoSecundario),
              ],
            ),
          ),
        );

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PildoraEstado(o.estado),
              const Spacer(),
              Text('Entró ${haceCuanto(o.fechaEntrada)}',
                  style: const TextStyle(color: Paleta.textoSecundario)),
            ],
          ),
          const SizedBox(height: 12),
          Text(o.matricula,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(o.vehiculoTexto,
              style: const TextStyle(color: Paleta.textoSecundario)),
          const Divider(height: 24),
          dato(Icons.person_outline, '${o.clienteNombre} · ${o.clienteTelefono}',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DetalleClientePantalla(clienteId: o.clienteId)))),
          dato(Icons.engineering_outlined, 'Mecánico: ${o.mecanicoNombre}'),
          dato(Icons.speed,
              'Kilometraje de entrada: ${numero(o.kilometrajeEntrada)} km'),
          dato(Icons.report_problem_outlined, o.problema),
        ],
      ),
    );
  }

  /// Contenedor común para las tres secciones expandibles.
  Widget _seccion({
    required IconData icono,
    required String titulo,
    required String resumen,
    required List<Widget> hijos,
    bool abierta = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Paleta.tarjeta,
        borderRadius: BorderRadius.circular(kRadio),
        border: Border.all(color: Paleta.borde),
      ),
      // ClipRRect recorta el fondo del ExpansionTile a las esquinas redondas.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kRadio),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            initiallyExpanded: abierta,
            // Sin las líneas que ExpansionTile dibuja por defecto.
            shape: const Border(),
            collapsedShape: const Border(),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Paleta.primarioSuave,
              child: Icon(icono, size: 20, color: Paleta.primarioOscuro),
            ),
            title: Text(titulo,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(resumen),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: hijos,
          ),
        ),
      ),
    );
  }

  Widget _seccionTrabajos(bool editable) {
    return StreamBuilder<List<Trabajo>>(
      stream: _trabajos,
      builder: (context, snap) {
        final lista = snap.data ?? const <Trabajo>[];
        final suma = lista.fold<double>(0, (s, t) => s + t.precio);
        return _seccion(
          icono: Icons.handyman_outlined,
          titulo: 'Trabajos (mano de obra)',
          resumen: '${lista.length} · ${dinero(suma)}',
          abierta: editable,
          hijos: [
            if (lista.isEmpty)
              const _Vacio('Todavía no hay trabajos registrados.'),
            for (final t in lista)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(t.descripcion),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dinero(t.precio),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (editable)
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _eliminarTrabajo(t),
                      ),
                  ],
                ),
              ),
            if (editable)
              _BotonAgregar('Agregar trabajo', onPressed: _agregarTrabajo),
          ],
        );
      },
    );
  }

  Widget _seccionRepuestos(bool editable) {
    return StreamBuilder<List<RepuestoUsadoDetalle>>(
      stream: _repuestos,
      builder: (context, snap) {
        final lista = snap.data ?? const <RepuestoUsadoDetalle>[];
        final suma = lista.fold<double>(0, (s, l) => s + l.subtotal);
        return _seccion(
          icono: Icons.settings_suggest_outlined,
          titulo: 'Repuestos',
          resumen: '${lista.length} · ${dinero(suma)}',
          hijos: [
            if (lista.isEmpty) const _Vacio('No se han usado repuestos.'),
            for (final l in lista)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(l.nombre),
                subtitle: Text(
                    '${l.codigo} · ${l.cantidad} × ${dinero(l.precioUnitario)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dinero(l.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (editable)
                      IconButton(
                        tooltip: 'Devolver al inventario',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _devolverRepuesto(l),
                      ),
                  ],
                ),
              ),
            if (editable)
              _BotonAgregar('Usar repuesto del inventario',
                  onPressed: _usarRepuesto),
          ],
        );
      },
    );
  }

  Widget _seccionPagos(OrdenResumen o) {
    final puedeCobrar = o.estado != EstadoOrden.cancelada && o.saldo > 0.009;
    return StreamBuilder<List<Pago>>(
      stream: _pagos,
      builder: (context, snap) {
        final lista = snap.data ?? const <Pago>[];
        return _seccion(
          icono: Icons.payments_outlined,
          titulo: 'Pagos',
          resumen: '${lista.length} · ${dinero(o.pagado)} cobrado',
          abierta: o.estado == EstadoOrden.lista,
          hijos: [
            if (lista.isEmpty) const _Vacio('Aún no se ha cobrado nada.'),
            for (final p in lista)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(p.metodo == 'Efectivo'
                    ? Icons.money
                    : Icons.account_balance_outlined),
                title: Text(dinero(p.monto),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p.metodo} · ${fechaHora(p.fecha)}'),
                trailing: IconButton(
                  tooltip: 'Eliminar pago',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminarPago(p),
                ),
              ),
            if (puedeCobrar)
              _BotonAgregar('Registrar pago',
                  onPressed: () => _registrarPago(o)),
          ],
        );
      },
    );
  }
}

/// Texto gris para secciones vacías.
class _Vacio extends StatelessWidget {
  final String texto;
  const _Vacio(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(texto, style: const TextStyle(color: Paleta.textoSecundario)),
      );
}

/// Botón "+ Agregar ..." al final de cada sección.
class _BotonAgregar extends StatelessWidget {
  final String texto;
  final VoidCallback onPressed;
  const _BotonAgregar(this.texto, {required this.onPressed});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(texto),
          onPressed: onPressed,
        ),
      );
}
