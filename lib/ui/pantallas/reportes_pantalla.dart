// =============================================================================
// reportes_pantalla.dart
// Reportes para el dueño, en UNA sola página desplazable con secciones:
//   1. Facturación por período: ChoiceChips Hoy / Esta semana / Este mes /
//      Personalizado (showDateRangePicker). Muestra lo facturado (mano de obra
//      + repuestos de las órdenes ENTREGADAS), la cantidad de órdenes, lo
//      cobrado en el período y la lista de esas órdenes.
//   2. Deudores: clientes con saldo pendiente y su teléfono.
//   3. Carga por mecánico con LinearProgressIndicator.
//   4. Repuestos por agotarse.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import '../widgets/estados_vista.dart';
import '../widgets/tarjeta.dart';
import 'detalle_cliente_pantalla.dart';
import 'detalle_orden_pantalla.dart';
import 'inventario_pantalla.dart';

/// Atajos de período para la facturación.
enum Periodo {
  hoy('Hoy'),
  semana('Esta semana'),
  mes('Este mes'),
  personalizado('Personalizado');

  final String etiqueta;
  const Periodo(this.etiqueta);
}

class ReportesPantalla extends StatefulWidget {
  const ReportesPantalla({super.key});

  @override
  State<ReportesPantalla> createState() => _ReportesPantallaState();
}

class _ReportesPantallaState extends State<ReportesPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  late final Stream<List<Deudor>> _deudores = repo.watchDeudores();
  late final Stream<List<CargaMecanico>> _carga = repo.watchCargaMecanicos();
  late final Stream<List<Repuesto>> _bajos = repo.watchRepuestosBajos();

  Periodo _periodo = Periodo.mes;
  late DateTime _desde = _inicioDelMes(DateTime.now());
  DateTime _hasta = DateTime.now();

  /// Depende del período: null = hay que recrearlo en build.
  Stream<ReporteFacturacion>? _facturacion;

  static DateTime _inicioDelMes(DateTime d) => DateTime(d.year, d.month, 1);

  Future<void> _elegirPeriodo(Periodo p) async {
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    DateTime desde = base;
    DateTime hasta = base;
    switch (p) {
      case Periodo.hoy:
        desde = base;
      case Periodo.semana:
        // La semana empieza el lunes (weekday 1).
        desde = base.subtract(Duration(days: base.weekday - 1));
      case Periodo.mes:
        desde = _inicioDelMes(base);
      case Periodo.personalizado:
        final rango = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(hoy.year + 1, 12, 31),
          initialDateRange: DateTimeRange(start: _desde, end: _hasta),
          helpText: 'Período de facturación',
          saveText: 'Aplicar',
        );
        if (rango == null) return; // el usuario canceló
        desde = rango.start;
        hasta = rango.end;
    }
    if (!mounted) return;
    setState(() {
      _periodo = p;
      _desde = desde;
      _hasta = hasta;
      _facturacion = null; // se recrea con las nuevas fechas
    });
  }

  void _abrir(Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    _facturacion ??= repo.watchFacturacion(_desde, _hasta);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const TituloSeccion('Facturación', icono: Icons.receipt_long_outlined),
          _seccionFacturacion(),
          const TituloSeccion('Deudores', icono: Icons.account_balance_wallet_outlined),
          _seccionDeudores(),
          const TituloSeccion('Carga por mecánico',
              icono: Icons.engineering_outlined),
          _seccionCarga(),
          const TituloSeccion('Stock por agotarse',
              icono: Icons.inventory_2_outlined),
          _seccionStock(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Facturación
  // ---------------------------------------------------------------------------
  Widget _seccionFacturacion() {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in Periodo.values)
                ChoiceChip(
                  label: Text(p.etiqueta),
                  selected: _periodo == p,
                  selectedColor: Paleta.primarioSuave,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  // "Personalizado" se puede volver a tocar para cambiar fechas.
                  onSelected: (_) => _elegirPeriodo(p),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Del ${fecha(_desde)} al ${fecha(_hasta)}',
              style: const TextStyle(color: Paleta.textoSecundario)),
          const SizedBox(height: 8),
          StreamBuilder<ReporteFacturacion>(
            stream: _facturacion,
            builder: (context, snap) {
              if (snap.hasError) return MensajeError(snap.error);
              if (!snap.hasData) return const LinearProgressIndicator();
              final r = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Facturado (órdenes entregadas)'),
                  Text(dinero(r.facturado),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Paleta.primarioOscuro)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniDato('Mano de obra', dinero(r.manoObra)),
                      _MiniDato('Repuestos', dinero(r.repuestos)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MiniDato('Órdenes', '${r.cantidad}'),
                      _MiniDato('Cobrado en el período', dinero(r.cobrado),
                          color: Paleta.exito),
                    ],
                  ),
                  if (r.ordenes.isNotEmpty)
                    ExpansionTile(
                        // Sin las líneas divisorias por defecto.
                        shape: const Border(),
                        collapsedShape: const Border(),
                        tilePadding: EdgeInsets.zero,
                        title: Text('Ver las ${r.cantidad} órdenes'),
                        children: [
                          for (final o in r.ordenes)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('#${o.id} · ${o.matricula} · '
                                  '${o.clienteNombre}'),
                              subtitle: Text(o.fechaEntrega == null
                                  ? ''
                                  : 'Entregada el ${fecha(o.fechaEntrega!)}'),
                              trailing: Text(dinero(o.total),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              onTap: () =>
                                  _abrir(DetalleOrdenPantalla(ordenId: o.id)),
                            ),
                        ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('No se entregaron órdenes en este período.',
                          style: TextStyle(color: Paleta.textoSecundario)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Deudores
  // ---------------------------------------------------------------------------
  Widget _seccionDeudores() {
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: StreamBuilder<List<Deudor>>(
        stream: _deudores,
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Nadie debe dinero. ¡Todo cobrado!',
                  style: TextStyle(color: Paleta.exito)),
            );
          }
          final total = lista.fold<double>(0, (s, d) => s + d.saldo);
          return Column(
            children: [
              ListTile(
                title: const Text('Total por cobrar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(dinero(total),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Paleta.acento)),
              ),
              const Divider(height: 1),
              for (final d in lista)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Paleta.acentoSuave,
                    child: Text(iniciales(d.nombre),
                        style: const TextStyle(color: Paleta.acento)),
                  ),
                  title: Text(d.nombre),
                  subtitle: Text('${d.telefono} · ${d.ordenesConSaldo} '
                      'orden(es)'),
                  trailing: Text(dinero(d.saldo),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () =>
                      _abrir(DetalleClientePantalla(clienteId: d.clienteId)),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Carga por mecánico
  // ---------------------------------------------------------------------------
  Widget _seccionCarga() {
    return Tarjeta(
      child: StreamBuilder<List<CargaMecanico>>(
        stream: _carga,
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          final activos = snap.data!.where((c) => c.mecanico.activo).toList();
          if (activos.isEmpty) return const Text('No hay mecánicos activos.');
          // La barra es relativa al total de órdenes abiertas del taller.
          final total = activos.fold<int>(0, (s, c) => s + c.abiertas);
          return Column(
            children: [
              for (final c in activos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(c.mecanico.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text('${c.abiertas} abiertas'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      BarraNivel(
                          valor: total == 0 ? 0 : c.abiertas / total, alto: 10),
                      const SizedBox(height: 4),
                      Text(
                        'Recibidas/diagnóstico: ${c.enDiagnostico} · '
                        'Reparación: ${c.enReparacion} · Listas: ${c.listas}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Stock por agotarse
  // ---------------------------------------------------------------------------
  Widget _seccionStock() {
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onTap: () => _abrir(const InventarioPantalla(soloBajos: true)),
      child: StreamBuilder<List<Repuesto>>(
        stream: _bajos,
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Todos los repuestos tienen existencias suficientes.',
                  style: TextStyle(color: Paleta.exito)),
            );
          }
          return Column(
            children: [
              for (final r in lista)
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: Paleta.aviso),
                  title: Text(r.nombre),
                  subtitle: Text(r.codigo),
                  trailing: Text('${r.existencias} / mín. ${r.stockMinimo}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E))),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Pequeño dato (etiqueta + valor) que ocupa la mitad de una fila.
class _MiniDato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? color;
  const _MiniDato(this.etiqueta, this.valor, {this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
            Text(valor,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: color ?? Paleta.texto)),
          ],
        ),
      );
}
