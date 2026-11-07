// =============================================================================
// inicio_pantalla.dart
// Pantalla de INICIO tipo "hub" (no hay barra inferior ni drawer):
//   1. Saludo según la hora ("Buenos días / Buenas tardes").
//   2. Resumen: órdenes en el taller por estado y total por cobrar.
//   3. Alerta de repuestos por agotarse (solo si hay).
//   4. Cuadrícula (GridView) de accesos grandes: Nueva orden, Órdenes,
//      Clientes, Inventario, Reportes, Mecánicos -> Navigator.push.
//   5. Carga de trabajo de cada mecánico.
// El botón de ajustes del AppBar abre una hoja inferior con "Cargar datos de
// ejemplo" y la gestión de mecánicos.
// Todo es reactivo: los StreamBuilder se actualizan solos al cambiar la BD.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import '../widgets/mensajes.dart';
import '../widgets/pildora_estado.dart';
import '../widgets/tarjeta.dart';
import 'clientes_pantalla.dart';
import 'inventario_pantalla.dart';
import 'mecanicos_pantalla.dart';
import 'nueva_orden_pantalla.dart';
import 'ordenes_pantalla.dart';
import 'reportes_pantalla.dart';

class InicioPantalla extends StatefulWidget {
  const InicioPantalla({super.key});

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  // Campos "late": se evalúan la primera vez que se usan (en build), cuando
  // el context ya puede consultar el InheritedWidget TallerScope. Así cada
  // Stream se crea UNA sola vez y no se reinicia en cada redibujado.
  late final RepositorioTaller repo = TallerScope.of(context);
  late final Stream<Map<EstadoOrden, int>> _conteo = repo.watchConteoPorEstado();
  late final Stream<List<Deudor>> _deudores = repo.watchDeudores();
  late final Stream<List<Repuesto>> _bajos = repo.watchRepuestosBajos();
  late final Stream<List<CargaMecanico>> _carga = repo.watchCargaMecanicos();

  /// Atajo para abrir otra pantalla.
  void _ir(Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  /// Hoja inferior de ajustes.
  void _abrirAjustes() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (hoja) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Ajustes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Cargar datos de ejemplo'),
              subtitle: const Text('Clientes, vehículos y órdenes de prueba'),
              onTap: () {
                Navigator.pop(hoja); // cierra la hoja
                _cargarDemo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.engineering_outlined),
              title: const Text('Gestionar mecánicos'),
              subtitle: const Text('Añadir, renombrar, activar o desactivar'),
              onTap: () {
                Navigator.pop(hoja);
                _ir(const MecanicosPantalla());
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _cargarDemo() async {
    final ok = await confirmar(
      context,
      titulo: 'Cargar datos de ejemplo',
      mensaje: 'Se crearán 3 clientes, 4 vehículos y varias órdenes de '
          'prueba. Solo funciona si todavía no hay clientes.',
      textoConfirmar: 'Cargar',
    );
    if (!ok || !mounted) return;
    await ejecutarAccion(context, repo.cargarDatosDemo,
        exito: 'Datos de ejemplo cargados');
  }

  @override
  Widget build(BuildContext context) {
    final estilos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.car_repair, color: Paleta.primario),
            SizedBox(width: 8),
            Text('El Pistón', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _abrirAjustes,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // 1. Saludo
          Text(saludoSegunHora(DateTime.now()),
              style: estilos.headlineSmall),
          Text('Hoy es ${fecha(DateTime.now())}. ¿Qué vamos a hacer?',
              style: const TextStyle(color: Paleta.textoSecundario)),
          const SizedBox(height: 16),

          // 2. Resumen
          _resumen(),

          // 3. Alerta de stock bajo
          _alertaStock(),

          // 4. Accesos
          const TituloSeccion('Accesos rápidos', icono: Icons.apps),
          GridView.count(
            crossAxisCount: 2,
            // Dentro de un ListView: la cuadrícula toma solo el alto que
            // necesita y no se desplaza por su cuenta.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.0,
            children: [
              _Acceso(
                icono: Icons.add_circle_outline,
                titulo: 'Nueva orden',
                detalle: 'Recibir un vehículo',
                destacado: true,
                onTap: () => _ir(const NuevaOrdenPantalla()),
              ),
              _Acceso(
                icono: Icons.assignment_outlined,
                titulo: 'Órdenes',
                detalle: 'En el taller y entregadas',
                onTap: () => _ir(const OrdenesPantalla()),
              ),
              _Acceso(
                icono: Icons.people_alt_outlined,
                titulo: 'Clientes',
                detalle: 'Datos, vehículos e historial',
                onTap: () => _ir(const ClientesPantalla()),
              ),
              _Acceso(
                icono: Icons.inventory_2_outlined,
                titulo: 'Inventario',
                detalle: 'Repuestos y existencias',
                onTap: () => _ir(const InventarioPantalla()),
              ),
              _Acceso(
                icono: Icons.insights_outlined,
                titulo: 'Reportes',
                detalle: 'Facturación y deudores',
                onTap: () => _ir(const ReportesPantalla()),
              ),
              _Acceso(
                icono: Icons.engineering_outlined,
                titulo: 'Mecánicos',
                detalle: 'Equipo del taller',
                onTap: () => _ir(const MecanicosPantalla()),
              ),
            ],
          ),

          // 5. Carga por mecánico
          const TituloSeccion('Carga de los mecánicos',
              icono: Icons.engineering_outlined),
          _cargaMecanicos(),
        ],
      ),
    );
  }

  /// Tarjeta con el número de órdenes en el taller, las píldoras por estado
  /// y el total por cobrar (suma de saldos de los deudores).
  Widget _resumen() {
    return Tarjeta(
      child: StreamBuilder<Map<EstadoOrden, int>>(
        stream: _conteo,
        builder: (context, snap) {
          final conteo = snap.data ?? const <EstadoOrden, int>{};
          final abiertas = EstadoOrdenX.abiertos
              .fold<int>(0, (s, e) => s + (conteo[e] ?? 0));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Cifra(
                      etiqueta: 'En el taller',
                      valor: '$abiertas',
                      color: Paleta.primarioOscuro,
                      onTap: () => _ir(const OrdenesPantalla()),
                    ),
                  ),
                  Container(width: 1, height: 48, color: Paleta.borde),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<List<Deudor>>(
                      stream: _deudores,
                      builder: (context, s) {
                        final total = (s.data ?? const <Deudor>[])
                            .fold<double>(0, (t, d) => t + d.saldo);
                        return _Cifra(
                          etiqueta: 'Por cobrar',
                          valor: dinero(total),
                          color: total > 0 ? Paleta.acento : Paleta.exito,
                          onTap: () => _ir(const ReportesPantalla()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Una píldora por cada estado abierto que tenga órdenes.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in EstadoOrdenX.abiertos)
                    if ((conteo[e] ?? 0) > 0)
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => _ir(OrdenesPantalla(
                            filtroInicial: e == EstadoOrden.lista
                                ? FiltroOrdenes.listas
                                : FiltroOrdenes.abiertas)),
                        child: PildoraEstado(e,
                            texto: '${conteo[e]} · ${e.etiqueta}'),
                      ),
                  if (abiertas == 0)
                    const Text('No hay vehículos en el taller ahora mismo.',
                        style: TextStyle(color: Paleta.textoSecundario)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Alerta ámbar con los repuestos por agotarse. Si no hay, no ocupa espacio.
  Widget _alertaStock() {
    return StreamBuilder<List<Repuesto>>(
      stream: _bajos,
      builder: (context, snap) {
        final lista = snap.data ?? const <Repuesto>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        final nombres = lista.take(3).map((r) => r.nombre).join(', ');
        return Tarjeta(
          color: Paleta.avisoSuave,
          colorBorde: Paleta.aviso,
          onTap: () => _ir(const InventarioPantalla(soloBajos: true)),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFF92400E), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lista.length == 1
                          ? '1 repuesto por agotarse'
                          : '${lista.length} repuestos por agotarse',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E)),
                    ),
                    Text(
                      lista.length > 3 ? '$nombres…' : nombres,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF92400E)),
            ],
          ),
        );
      },
    );
  }

  /// Carga de los mecánicos activos con una barra relativa al más ocupado.
  Widget _cargaMecanicos() {
    return Tarjeta(
      child: StreamBuilder<List<CargaMecanico>>(
        stream: _carga,
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          final activos =
              snap.data!.where((c) => c.mecanico.activo).toList();
          if (activos.isEmpty) {
            return const Text('No hay mecánicos activos.');
          }
          final maximo = activos.fold<int>(
              1, (m, c) => c.abiertas > m ? c.abiertas : m);
          return Column(
            children: [
              for (final c in activos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Paleta.primarioSuave,
                        child: Text(iniciales(c.mecanico.nombre),
                            style: const TextStyle(
                                fontSize: 12, color: Paleta.primarioOscuro)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.mecanico.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            BarraNivel(valor: c.abiertas / maximo),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${c.abiertas}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Número grande con su etiqueta (en la tarjeta de resumen).
class _Cifra extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color color;
  final VoidCallback onTap;

  const _Cifra({
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(color: Paleta.textoSecundario)),
          // FittedBox reduce el texto si el importe es muy largo.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Acceso grande de la cuadrícula del inicio.
class _Acceso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  final bool destacado;

  const _Acceso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    // El acceso "Nueva orden" va relleno de color primario: es la tarea
    // más frecuente de la recepcionista.
    final fondo = destacado ? Paleta.primario : Paleta.tarjeta;
    final colorTexto = destacado ? Colors.white : Paleta.texto;
    return Tarjeta(
      margin: EdgeInsets.zero,
      color: fondo,
      colorBorde: destacado ? Paleta.primario : Paleta.borde,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                destacado ? Colors.white.withAlpha(51) : Paleta.primarioSuave,
            child: Icon(icono,
                color: destacado ? Colors.white : Paleta.primarioOscuro),
          ),
          const Spacer(),
          Text(titulo,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: colorTexto)),
          Text(detalle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: destacado
                      ? Colors.white.withAlpha(220)
                      : Paleta.textoSecundario)),
        ],
      ),
    );
  }
}
