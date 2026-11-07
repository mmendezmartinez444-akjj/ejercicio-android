// =============================================================================
// vehiculo_pantalla.dart
// Ficha de un vehículo: datos (matrícula, marca, modelo, año, último
// kilometraje, dueño) e HISTORIAL de servicios (todas sus órdenes).
// Desde aquí se puede editar o eliminar el vehículo y abrir el asistente de
// nueva orden con el cliente y el vehículo ya elegidos.
// =============================================================================
import 'package:flutter/material.dart';

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

class VehiculoPantalla extends StatefulWidget {
  final int vehiculoId;
  const VehiculoPantalla({super.key, required this.vehiculoId});

  @override
  State<VehiculoPantalla> createState() => _VehiculoPantallaState();
}

class _VehiculoPantallaState extends State<VehiculoPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  int get _id => widget.vehiculoId;

  late final Stream<Vehiculo?> _vehiculo = repo.watchVehiculo(_id);
  late final Stream<List<OrdenResumen>> _historial =
      repo.watchOrdenes(vehiculoId: _id);

  /// El dueño depende del vehículo: el Stream se crea cuando llega el
  /// vehículo (y no cambia, porque un vehículo no cambia de dueño en la app).
  Stream<Cliente?>? _dueno;

  Future<void> _editar(Vehiculo v) async {
    final ok = await abrirDialogo(
      context,
      DialogoVehiculo(
        vehiculo: v,
        guardar: (d) => repo.actualizarVehiculo(v.id,
            matricula: d.matricula,
            marca: d.marca,
            modelo: d.modelo,
            anio: d.anio,
            kilometraje: d.kilometraje),
      ),
    );
    if (ok && mounted) mostrarExito(context, 'Vehículo actualizado');
  }

  Future<void> _eliminar(Vehiculo v) async {
    final ok = await confirmar(context,
        titulo: 'Eliminar vehículo',
        mensaje: '¿Eliminar ${v.matricula}? Solo es posible si nunca ha '
            'tenido órdenes.',
        textoConfirmar: 'Eliminar',
        peligroso: true);
    if (!ok || !mounted) return;
    final hecho = await ejecutarAccion(
        context, () => repo.eliminarVehiculo(v.id),
        exito: 'Vehículo eliminado');
    if (hecho && mounted) Navigator.pop(context);
  }

  Future<void> _nuevaOrden(Vehiculo v) async {
    final c = await repo.watchCliente(v.clienteId).first;
    if (c == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => NuevaOrdenPantalla(cliente: c, vehiculo: v)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Vehiculo?>(
      stream: _vehiculo,
      builder: (context, snap) {
        if (!snap.hasData &&
            snap.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const Cargando());
        }
        final v = snap.data;
        if (v == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const MensajeVacio(
                icono: Icons.no_crash_outlined,
                titulo: 'Vehículo no encontrado'),
          );
        }
        _dueno ??= repo.watchCliente(v.clienteId);
        return Scaffold(
          appBar: AppBar(
            title: Text(v.matricula),
            actions: [
              IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editar(v)),
              IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _eliminar(v)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Nueva orden'),
            onPressed: () => _nuevaOrden(v),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            children: [
              _datos(v),
              const TituloSeccion('Historial de servicios',
                  icono: Icons.history),
              StreamBuilder<List<OrdenResumen>>(
                stream: _historial,
                builder: (context, s) {
                  if (!s.hasData) return const Cargando();
                  final lista = s.data!;
                  if (lista.isEmpty) {
                    return const MensajeVacio(
                        icono: Icons.history,
                        titulo: 'Sin servicios todavía');
                  }
                  return Column(children: [
                    for (final o in lista) ...[
                      // Kilometraje con el que llegó en esa visita.
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                            '${fecha(o.fechaEntrada)} · '
                            '${numero(o.kilometrajeEntrada)} km',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      TarjetaOrden(o, mostrarVehiculo: false),
                    ],
                  ]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _datos(Vehiculo v) {
    Widget dato(String etiqueta, String valor) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta,
                  style: const TextStyle(color: Paleta.textoSecundario)),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Tarjeta(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Paleta.primarioSuave,
                child: Icon(Icons.directions_car_filled_outlined,
                    color: Paleta.primarioOscuro),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${v.marca} ${v.modelo}',
                        style: Theme.of(context).textTheme.titleLarge),
                    StreamBuilder<Cliente?>(
                      stream: _dueno,
                      builder: (context, s) => Text(
                        s.data == null ? '' : 'Dueño: ${s.data!.nombre}',
                        style: const TextStyle(color: Paleta.textoSecundario),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            children: [
              dato('Matrícula', v.matricula),
              dato('Año', '${v.anio}'),
              dato('Último km', numero(v.kilometraje)),
            ],
          ),
        ],
      ),
    );
  }
}
