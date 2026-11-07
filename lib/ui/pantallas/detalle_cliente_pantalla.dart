// =============================================================================
// detalle_cliente_pantalla.dart
// Ficha del cliente:
//   - Cabecera con avatar de iniciales, dirección y botón "llamar" que
//     muestra el teléfono en grande (sin paquetes externos; se puede copiar).
//   - Saldo pendiente (órdenes listas o entregadas con dinero por cobrar).
//   - Vehículos como tarjetas horizontales (ListView horizontal); cada una
//     abre el historial del vehículo y permite crear una nueva orden.
//   - Historial de todas sus órdenes.
//   - Editar / eliminar el cliente desde el AppBar.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import '../widgets/dialogos.dart';
import '../widgets/estados_vista.dart';
import '../widgets/mensajes.dart';
import '../widgets/tarjeta.dart';
import '../widgets/tarjeta_orden.dart';
import 'nueva_orden_pantalla.dart';
import 'vehiculo_pantalla.dart';

class DetalleClientePantalla extends StatefulWidget {
  final int clienteId;
  const DetalleClientePantalla({super.key, required this.clienteId});

  @override
  State<DetalleClientePantalla> createState() => _DetalleClientePantallaState();
}

class _DetalleClientePantallaState extends State<DetalleClientePantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  int get _id => widget.clienteId;

  late final Stream<Cliente?> _cliente = repo.watchCliente(_id);
  late final Stream<List<Vehiculo>> _vehiculos =
      repo.watchVehiculosDeCliente(_id);
  // Este Stream lo escuchan DOS StreamBuilder (saldo e historial): los
  // Stream de Drift son "broadcast" y admiten varios oyentes a la vez.
  late final Stream<List<OrdenResumen>> _ordenes =
      repo.watchOrdenes(clienteId: _id);

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  /// "Llamar": muestra el número en grande para marcarlo desde el teléfono.
  void _mostrarTelefono(Cliente c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.call, color: Paleta.primario, size: 36),
        title: Text(c.nombre),
        content: SelectableText(
          c.telefono,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: c.telefono));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) mostrarExito(context, 'Teléfono copiado');
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editar(Cliente c) async {
    final ok = await abrirDialogo(
      context,
      DialogoCliente(
        cliente: c,
        guardar: (d) => repo.actualizarCliente(c.id,
            nombre: d.nombre, telefono: d.telefono, direccion: d.direccion),
      ),
    );
    if (ok && mounted) mostrarExito(context, 'Cliente actualizado');
  }

  Future<void> _eliminar(Cliente c) async {
    final ok = await confirmar(context,
        titulo: 'Eliminar cliente',
        mensaje: '¿Eliminar a ${c.nombre}? Solo es posible si no tiene '
            'vehículos registrados.',
        textoConfirmar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    final hecho = await ejecutarAccion(
        context, () => repo.eliminarCliente(c.id),
        exito: 'Cliente eliminado');
    if (hecho && mounted) Navigator.pop(context);
  }

  Future<void> _agregarVehiculo() async {
    final ok = await abrirDialogo(
      context,
      DialogoVehiculo(
        guardar: (d) => repo.crearVehiculo(
          clienteId: _id,
          matricula: d.matricula,
          marca: d.marca,
          modelo: d.modelo,
          anio: d.anio,
          kilometraje: d.kilometraje,
        ),
      ),
    );
    if (ok && mounted) mostrarExito(context, 'Vehículo registrado');
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Cliente?>(
      stream: _cliente,
      builder: (context, snap) {
        if (!snap.hasData &&
            snap.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const Cargando());
        }
        final c = snap.data;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const MensajeVacio(
                icono: Icons.person_off_outlined,
                titulo: 'Cliente no encontrado'),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ficha del cliente'),
            actions: [
              IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editar(c)),
              IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminar(c)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _cabecera(c),
              TituloSeccion(
                'Vehículos',
                icono: Icons.directions_car_outlined,
                accion: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                  onPressed: _agregarVehiculo,
                ),
              ),
              _vehiculosHorizontales(c),
              const TituloSeccion('Historial de órdenes', icono: Icons.history),
              _historial(),
            ],
          ),
        );
      },
    );
  }

  Widget _cabecera(Cliente c) {
    return Tarjeta(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Paleta.primarioSuave,
            child: Text(iniciales(c.nombre),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Paleta.primarioOscuro)),
          ),
          const SizedBox(height: 10),
          Text(c.nombre,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          if (c.direccion != null)
            Text(c.direccion!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Paleta.textoSecundario)),
          Text('Cliente desde ${fecha(c.creadoEn)}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          FilledButton.icon(
            icon: const Icon(Icons.call),
            label: Text(c.telefono),
            onPressed: () => _mostrarTelefono(c),
          ),
          const SizedBox(height: 14),
          // Saldo pendiente: suma de saldos de órdenes listas o entregadas
          // (misma regla que el núcleo usa para los deudores).
          StreamBuilder<List<OrdenResumen>>(
            stream: _ordenes,
            builder: (context, snap) {
              final saldo = (snap.data ?? const <OrdenResumen>[])
                  .where((o) =>
                      o.estado == EstadoOrden.lista ||
                      o.estado == EstadoOrden.entregada)
                  .fold<double>(0, (s, o) => s + (o.saldo > 0 ? o.saldo : 0));
              final debe = saldo > 0.009;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: debe ? Paleta.acentoSuave : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(kRadioCampo),
                ),
                child: Text(
                  debe ? 'Saldo pendiente: ${dinero(saldo)}' : 'Está al día',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: debe ? Paleta.acento : Paleta.exito,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Tarjetas de vehículos desplazables en horizontal.
  Widget _vehiculosHorizontales(Cliente c) {
    return StreamBuilder<List<Vehiculo>>(
      stream: _vehiculos,
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final lista = snap.data!;
        if (lista.isEmpty) {
          return const Tarjeta(
            child: Text('Sin vehículos. Use "Agregar" para registrar uno.',
                style: TextStyle(color: Paleta.textoSecundario)),
          );
        }
        return SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: lista.length,
            separatorBuilder: (context, i) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _TarjetaVehiculo(cliente: c, vehiculo: lista[i]),
          ),
        );
      },
    );
  }

  Widget _historial() {
    return StreamBuilder<List<OrdenResumen>>(
      stream: _ordenes,
      builder: (context, snap) {
        if (!snap.hasData) return const Cargando();
        final lista = snap.data!;
        if (lista.isEmpty) {
          return const MensajeVacio(
              icono: Icons.history, titulo: 'Todavía no tiene órdenes');
        }
        return Column(children: [for (final o in lista) TarjetaOrden(o)]);
      },
    );
  }
}

/// Tarjeta de un vehículo dentro de la lista horizontal.
class _TarjetaVehiculo extends StatelessWidget {
  final Cliente cliente;
  final Vehiculo vehiculo;
  const _TarjetaVehiculo({required this.cliente, required this.vehiculo});

  @override
  Widget build(BuildContext context) {
    final v = vehiculo;
    return SizedBox(
      width: 230,
      child: Tarjeta(
        margin: EdgeInsets.zero,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VehiculoPantalla(vehiculoId: v.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_filled_outlined,
                    color: Paleta.primario),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(v.matricula,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${v.marca} ${v.modelo} (${v.anio})',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${numero(v.kilometraje)} km',
                style: const TextStyle(color: Paleta.textoSecundario)),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Nueva orden'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NuevaOrdenPantalla(cliente: cliente, vehiculo: v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
