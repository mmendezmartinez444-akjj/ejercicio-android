// =============================================================================
// clientes_pantalla.dart
// Lista de clientes con búsqueda (por nombre, teléfono o matrícula de alguno
// de sus vehículos). Cada fila muestra un avatar con las iniciales, el
// teléfono, cuántos vehículos tiene y su saldo pendiente.
// El botón flotante crea un cliente (AlertDialog) y abre su ficha.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/dialogos.dart';
import '../widgets/estados_vista.dart';
import '../widgets/tarjeta.dart';
import 'detalle_cliente_pantalla.dart';

class ClientesPantalla extends StatefulWidget {
  const ClientesPantalla({super.key});

  @override
  State<ClientesPantalla> createState() => _ClientesPantallaState();
}

class _ClientesPantallaState extends State<ClientesPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  String _busqueda = '';
  Stream<List<ClienteResumen>>? _stream; // se recrea al cambiar la búsqueda

  void _abrirFicha(int clienteId) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DetalleClientePantalla(clienteId: clienteId)),
      );

  Future<void> _nuevoCliente() async {
    int? nuevoId;
    final ok = await abrirDialogo(
      context,
      DialogoCliente(
        guardar: (d) async {
          nuevoId = await repo.crearCliente(
              nombre: d.nombre, telefono: d.telefono, direccion: d.direccion);
        },
      ),
    );
    final id = nuevoId;
    if (ok && id != null && mounted) _abrirFicha(id);
  }

  @override
  Widget build(BuildContext context) {
    _stream ??= repo.watchClientes(busqueda: _busqueda);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Nuevo cliente'),
        onPressed: _nuevoCliente,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: CampoBusqueda(
              pista: 'Buscar por nombre, teléfono o matrícula',
              onCambio: (t) => setState(() {
                _busqueda = t;
                _stream = null;
              }),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ClienteResumen>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) return MensajeError(snap.error);
                if (!snap.hasData) return const Cargando();
                final lista = snap.data!;
                if (lista.isEmpty) {
                  return const MensajeVacio(
                    icono: Icons.people_alt_outlined,
                    titulo: 'No hay clientes',
                    detalle: 'Registre uno con el botón "Nuevo cliente".',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  itemCount: lista.length,
                  itemBuilder: (context, i) => _FilaCliente(
                    lista[i],
                    onTap: () => _abrirFicha(lista[i].cliente.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaCliente extends StatelessWidget {
  final ClienteResumen r;
  final VoidCallback onTap;
  const _FilaCliente(this.r, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final debe = r.saldoPendiente > 0.009;
    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: debe ? Paleta.acentoSuave : Paleta.primarioSuave,
            child: Text(
              iniciales(r.cliente.nombre),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: debe ? Paleta.acento : Paleta.primarioOscuro,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.cliente.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${r.cliente.telefono} · ${r.vehiculos} vehículo(s)',
                    style: const TextStyle(color: Paleta.textoSecundario)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(debe ? dinero(r.saldoPendiente) : 'Al día',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: debe ? Paleta.acento : Paleta.exito,
                  )),
              if (debe)
                const Text('pendiente',
                    style: TextStyle(fontSize: 11, color: Paleta.textoSecundario)),
            ],
          ),
        ],
      ),
    );
  }
}
