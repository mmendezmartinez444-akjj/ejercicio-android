// =============================================================================
// dialogos_orden.dart
// Formularios (AlertDialog) que se usan dentro del detalle de una orden:
//   - DialogoTrabajo: descripción + precio de mano de obra.
//   - DialogoPago: monto, método (Efectivo/Transferencia) y botón
//     "Saldo completo" que rellena el importe pendiente.
//   - DialogoUsarRepuesto: buscador del inventario + cantidad.
// Todos reutilizan DialogoFormulario (dialogos.dart), que valida, llama a la
// función `guardar` y muestra dentro del diálogo los errores de negocio.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import 'campo_busqueda.dart';
import 'dialogos.dart';

// -----------------------------------------------------------------------------
// Trabajo (mano de obra)
// -----------------------------------------------------------------------------
class DialogoTrabajo extends StatefulWidget {
  final Future<void> Function(String descripcion, double precio) guardar;
  const DialogoTrabajo({super.key, required this.guardar});

  @override
  State<DialogoTrabajo> createState() => _DialogoTrabajoState();
}

class _DialogoTrabajoState extends State<DialogoTrabajo> {
  final _formKey = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _precio = TextEditingController();

  @override
  void dispose() {
    _descripcion.dispose();
    _precio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: 'Agregar trabajo',
      icono: Icons.handyman_outlined,
      formKey: _formKey,
      textoGuardar: 'Agregar',
      guardar: () =>
          widget.guardar(_descripcion.text, leerDinero(_precio.text) ?? 0),
      campos: [
        TextFormField(
          controller: _descripcion,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: decoracionCampo('Descripción',
              icono: Icons.notes, pista: 'Cambio de aceite'),
          validator: validarObligatorio,
        ),
        TextFormField(
          controller: _precio,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoracionCampo('Precio de mano de obra',
              icono: Icons.payments_outlined, sufijo: kMoneda),
          validator: validarDineroNoNegativo,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pago (abono)
// -----------------------------------------------------------------------------
class DialogoPago extends StatefulWidget {
  final double saldo;
  final Future<void> Function(double monto, String metodo) guardar;

  const DialogoPago({super.key, required this.saldo, required this.guardar});

  @override
  State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  static const _metodos = ['Efectivo', 'Transferencia'];

  final _formKey = GlobalKey<FormState>();
  final _monto = TextEditingController();
  String _metodo = _metodos.first;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: 'Registrar pago',
      icono: Icons.point_of_sale_outlined,
      formKey: _formKey,
      textoGuardar: 'Cobrar',
      guardar: () => widget.guardar(leerDinero(_monto.text) ?? 0, _metodo),
      campos: [
        Text('Saldo pendiente: ${dinero(widget.saldo)}',
            style: const TextStyle(
                color: Paleta.acento, fontWeight: FontWeight.w600)),
        TextFormField(
          controller: _monto,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoracionCampo('Monto recibido',
              icono: Icons.payments_outlined, sufijo: kMoneda),
          validator: (v) {
            final n = leerDinero(v ?? '');
            if (n == null || n <= 0) return 'Escriba un monto mayor que cero';
            if (n > widget.saldo + 0.009) return 'Supera el saldo pendiente';
            return null;
          },
        ),
        // Atajo: el cliente paga todo lo que debe.
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.done_all),
            label: const Text('Saldo completo'),
            onPressed: () =>
                _monto.text = widget.saldo.toStringAsFixed(2),
          ),
        ),
        // Método de pago con ChoiceChip (selección única).
        Wrap(
          spacing: 8,
          children: [
            for (final m in _metodos)
              ChoiceChip(
                label: Text(m),
                avatar: Icon(m == 'Efectivo'
                    ? Icons.money
                    : Icons.account_balance_outlined),
                selected: _metodo == m,
                onSelected: (_) => setState(() => _metodo = m),
              ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Usar repuesto del inventario
// -----------------------------------------------------------------------------
class DialogoUsarRepuesto extends StatefulWidget {
  final Future<void> Function(Repuesto repuesto, int cantidad) guardar;
  const DialogoUsarRepuesto({super.key, required this.guardar});

  @override
  State<DialogoUsarRepuesto> createState() => _DialogoUsarRepuestoState();
}

class _DialogoUsarRepuestoState extends State<DialogoUsarRepuesto> {
  // El repositorio se obtiene de forma "perezosa" (late): la primera vez que
  // se usa es en build, cuando el context ya puede leer el InheritedWidget.
  late final RepositorioTaller repo = TallerScope.of(context);

  final _formKey = GlobalKey<FormState>();
  final _cantidad = TextEditingController(text: '1');
  String _busqueda = '';
  Repuesto? _elegido;

  /// Stream del inventario filtrado. Se guarda para no recrearlo en cada
  /// build; se pone a null cuando cambia la búsqueda y se recrea en build.
  Stream<List<Repuesto>>? _stream;

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final r = _elegido;
    if (r == null) {
      throw const ReglaNegocioException('Elija un repuesto de la lista.');
    }
    await widget.guardar(r, leerEntero(_cantidad.text) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    _stream ??= repo.watchRepuestos(busqueda: _busqueda);
    return DialogoFormulario(
      titulo: 'Usar repuesto',
      icono: Icons.settings_suggest_outlined,
      formKey: _formKey,
      textoGuardar: 'Usar',
      guardar: _guardar,
      campos: [
        CampoBusqueda(
          pista: 'Buscar por nombre o código',
          onCambio: (t) => setState(() {
            _busqueda = t;
            _stream = null; // se recreará con el nuevo filtro
          }),
        ),
        SizedBox(
          height: 240,
          // Material transparente propio: el color de la fila seleccionada
          // (selectedTileColor) se pinta sobre este Material, que lo recorta a
          // estos 240 px; si no, al desplazar la lista se vería fuera de ella.
          child: Material(
            type: MaterialType.transparency,
            child: StreamBuilder<List<Repuesto>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lista = snap.data!;
                if (lista.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }
                return ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final r = lista[i];
                    final agotado = r.existencias <= 0;
                    final seleccionado = _elegido?.id == r.id;
                    return ListTile(
                      enabled: !agotado,
                      selected: seleccionado,
                      selectedTileColor: Paleta.primarioSuave,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kRadioCampo)),
                      leading: Icon(seleccionado
                          ? Icons.check_circle
                          : Icons.inventory_2_outlined),
                      title: Text(r.nombre),
                      subtitle: Text(
                          '${r.codigo} · ${dinero(r.precioVenta)} · '
                          '${agotado ? 'Agotado' : 'Hay ${r.existencias}'}'),
                      onTap: () => setState(() => _elegido = r),
                    );
                  },
                );
              },
            ),
          ),
        ),
        TextFormField(
          controller: _cantidad,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: decoracionCampo('Cantidad', icono: Icons.numbers),
          validator: (v) {
            final n = leerEntero(v ?? '');
            if (n == null || n <= 0) return 'Debe ser mayor que cero';
            final r = _elegido;
            if (r != null && n > r.existencias) {
              return 'Solo hay ${r.existencias} en existencia';
            }
            return null;
          },
        ),
      ],
    );
  }
}
