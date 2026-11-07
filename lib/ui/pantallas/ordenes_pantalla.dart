// =============================================================================
// ordenes_pantalla.dart
// Lista de órdenes de servicio.
//   - Filtro con ChoiceChips: Abiertas (por defecto) / Listas para entregar /
//     Entregadas / Todas (incluye canceladas).
//   - Búsqueda redondeada por matrícula, cliente o problema.
//   - Cada orden se muestra con TarjetaOrden (píldora de estado y saldo).
//   - Botón flotante "Nueva orden" que abre el asistente.
// El Stream se guarda en el estado y solo se recrea cuando cambia el filtro o
// el texto buscado (evita parpadeos mientras se escribe).
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../tema.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/estados_vista.dart';
import '../widgets/tarjeta_orden.dart';
import 'nueva_orden_pantalla.dart';

/// Filtros disponibles en la lista de órdenes.
enum FiltroOrdenes {
  abiertas('Abiertas', Icons.build_circle_outlined),
  listas('Listas para entregar', Icons.check_circle_outline),
  entregadas('Entregadas', Icons.directions_car_filled_outlined),
  todas('Todas', Icons.list_alt);

  final String etiqueta;
  final IconData icono;
  const FiltroOrdenes(this.etiqueta, this.icono);

  /// Estados que incluye cada filtro (null = sin filtrar por estado).
  List<EstadoOrden>? get estados => switch (this) {
        FiltroOrdenes.abiertas => EstadoOrdenX.abiertos,
        FiltroOrdenes.listas => const [EstadoOrden.lista],
        FiltroOrdenes.entregadas => const [EstadoOrden.entregada],
        FiltroOrdenes.todas => null,
      };
}

class OrdenesPantalla extends StatefulWidget {
  final FiltroOrdenes filtroInicial;
  const OrdenesPantalla({super.key, this.filtroInicial = FiltroOrdenes.abiertas});

  @override
  State<OrdenesPantalla> createState() => _OrdenesPantallaState();
}

class _OrdenesPantallaState extends State<OrdenesPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  late FiltroOrdenes _filtro = widget.filtroInicial;
  String _busqueda = '';
  Stream<List<OrdenResumen>>? _stream; // null = hay que (re)crearlo

  /// Cambia filtro/búsqueda y fuerza a recrear el Stream en el próximo build.
  void _actualizar({FiltroOrdenes? filtro, String? busqueda}) {
    setState(() {
      _filtro = filtro ?? _filtro;
      _busqueda = busqueda ?? _busqueda;
      _stream = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _stream ??= repo.watchOrdenes(estados: _filtro.estados, busqueda: _busqueda);
    return Scaffold(
      appBar: AppBar(title: const Text('Órdenes')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nueva orden'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NuevaOrdenPantalla())),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: CampoBusqueda(
              pista: 'Buscar matrícula, cliente o problema',
              onCambio: (t) => _actualizar(busqueda: t),
            ),
          ),
          // Fila desplazable horizontal de ChoiceChips (selección única).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final f in FiltroOrdenes.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.etiqueta),
                      avatar: Icon(f.icono, size: 18),
                      selected: _filtro == f,
                      selectedColor: Paleta.primarioSuave,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      onSelected: (_) => _actualizar(filtro: f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<OrdenResumen>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) return MensajeError(snap.error);
                if (!snap.hasData) return const Cargando();
                final lista = snap.data!;
                if (lista.isEmpty) {
                  return MensajeVacio(
                    icono: Icons.assignment_outlined,
                    titulo: 'No hay órdenes aquí',
                    detalle: _busqueda.isEmpty
                        ? 'Cambie el filtro o registre una nueva orden.'
                        : 'Ninguna orden coincide con "$_busqueda".',
                  );
                }
                // ListView.builder crea solo las tarjetas visibles.
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: lista.length,
                  itemBuilder: (context, i) => TarjetaOrden(lista[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
