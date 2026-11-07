// =============================================================================
// inventario_pantalla.dart
// Inventario de repuestos:
//   - Búsqueda por nombre o código y filtro "Solo por agotarse" (FilterChip).
//   - Cada repuesto muestra una barra de nivel de stock relativa a 2 × su
//     mínimo (barra llena = el doble del mínimo o más) y la etiqueta
//     "Por agotarse" cuando existencias <= mínimo.
//   - Tocar un repuesto lo edita; el botón del carrito abre "Reabastecer".
//   - Botón flotante para crear un repuesto nuevo.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/base_datos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/dialogos.dart';
import '../widgets/estados_vista.dart';
import '../widgets/mensajes.dart';
import '../widgets/tarjeta.dart';

class InventarioPantalla extends StatefulWidget {
  /// Desde la alerta del inicio se abre ya filtrado.
  final bool soloBajos;
  const InventarioPantalla({super.key, this.soloBajos = false});

  @override
  State<InventarioPantalla> createState() => _InventarioPantallaState();
}

class _InventarioPantallaState extends State<InventarioPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  late bool _soloBajos = widget.soloBajos;
  String _busqueda = '';
  Stream<List<Repuesto>>? _stream;

  /// Abre el formulario para crear (r == null) o editar un repuesto.
  Future<void> _formulario([Repuesto? r]) async {
    final ok = await abrirDialogo(
      context,
      DialogoRepuesto(
        repuesto: r,
        guardar: (d) => repo.guardarRepuesto(
          id: r?.id,
          codigo: d.codigo,
          nombre: d.nombre,
          precioVenta: d.precio,
          existencias: d.existencias,
          stockMinimo: d.minimo,
        ),
      ),
    );
    if (ok && mounted) {
      mostrarExito(context, r == null ? 'Repuesto creado' : 'Repuesto guardado');
    }
  }

  Future<void> _reabastecer(Repuesto r) async {
    final ok = await abrirDialogo(
      context,
      DialogoCantidad(
        titulo: 'Reabastecer',
        detalle: '${r.nombre}\nHay ${r.existencias} (mínimo ${r.stockMinimo}).',
        guardar: (n) => repo.reabastecer(r.id, n),
      ),
    );
    if (ok && mounted) mostrarExito(context, 'Existencias actualizadas');
  }

  @override
  Widget build(BuildContext context) {
    _stream ??= repo.watchRepuestos(busqueda: _busqueda, soloBajos: _soloBajos);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nuevo repuesto'),
        onPressed: () => _formulario(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: CampoBusqueda(
              pista: 'Buscar por nombre o código',
              onCambio: (t) => setState(() {
                _busqueda = t;
                _stream = null;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Solo por agotarse'),
                avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                selected: _soloBajos,
                selectedColor: Paleta.avisoSuave,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                onSelected: (v) => setState(() {
                  _soloBajos = v;
                  _stream = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Repuesto>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) return MensajeError(snap.error);
                if (!snap.hasData) return const Cargando();
                final lista = snap.data!;
                if (lista.isEmpty) {
                  return MensajeVacio(
                    icono: Icons.inventory_2_outlined,
                    titulo: _soloBajos
                        ? '¡Nada por agotarse!'
                        : 'No hay repuestos',
                    detalle: _soloBajos
                        ? 'Todos los repuestos están por encima del mínimo.'
                        : null,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  itemCount: lista.length,
                  itemBuilder: (context, i) => _FilaRepuesto(
                    lista[i],
                    onTap: () => _formulario(lista[i]),
                    onReabastecer: () => _reabastecer(lista[i]),
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

class _FilaRepuesto extends StatelessWidget {
  final Repuesto r;
  final VoidCallback onTap;
  final VoidCallback onReabastecer;

  const _FilaRepuesto(this.r, {required this.onTap, required this.onReabastecer});

  @override
  Widget build(BuildContext context) {
    final bajo = r.existencias <= r.stockMinimo; // misma regla que el núcleo
    // Nivel relativo a 2 × mínimo. Si el mínimo es 0, la barra va llena
    // mientras haya existencias.
    final referencia = r.stockMinimo * 2;
    final nivel = referencia == 0
        ? (r.existencias > 0 ? 1.0 : 0.0)
        : r.existencias / referencia;
    return Tarjeta(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      colorBorde: bajo ? Paleta.aviso : Paleta.borde,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${r.codigo} · ${dinero(r.precioVenta)}',
                        style: const TextStyle(color: Paleta.textoSecundario)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Reabastecer',
                icon: const Icon(Icons.add_shopping_cart,
                    color: Paleta.primario),
                onPressed: onReabastecer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BarraNivel(
              valor: nivel,
              color: bajo ? Paleta.acento : Paleta.primario,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                    '${r.existencias} en existencia · mínimo ${r.stockMinimo}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (bajo)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Paleta.avisoSuave,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text('Por agotarse',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
