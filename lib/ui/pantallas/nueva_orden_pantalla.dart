// =============================================================================
// nueva_orden_pantalla.dart
// ASISTENTE paso a paso para recibir un vehículo (widget Stepper vertical):
//   1) Cliente: buscar uno existente o crearlo en línea. Si se escribe una
//      matrícula aparecen también los vehículos que coinciden (atajo que
//      salta directamente al paso 3).
//   2) Vehículo: elegir uno del cliente o registrar uno nuevo.
//   3) Problema reportado y kilometraje (precargado con el último registrado).
//   4) Mecánico: RadioListTile con la carga de trabajo de cada uno.
//   5) Confirmar: resumen -> crea la orden y abre su detalle.
// Cada paso se valida antes de avanzar (_continuar). Los clientes y vehículos
// nuevos se guardan al pulsar "Guardar y continuar", sin salir del flujo.
// =============================================================================

// RadioListTile.groupValue/onChanged están marcados como obsoletos a partir de
// Flutter 3.32 (sustituidos por RadioGroup, que no existe en 3.22). Se siguen
// usando para que el código compile en ambas versiones.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/dialogos.dart';
import '../widgets/mensajes.dart';
import '../widgets/tarjeta.dart';
import 'detalle_orden_pantalla.dart';

class NuevaOrdenPantalla extends StatefulWidget {
  /// Si se abre desde la ficha de un cliente o vehículo, llegan precargados
  /// y el asistente empieza en el paso correspondiente.
  final Cliente? cliente;
  final Vehiculo? vehiculo;

  const NuevaOrdenPantalla({super.key, this.cliente, this.vehiculo});

  @override
  State<NuevaOrdenPantalla> createState() => _NuevaOrdenPantallaState();
}

class _NuevaOrdenPantallaState extends State<NuevaOrdenPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);

  // Índices de los pasos (más legible que números sueltos).
  static const _pCliente = 0, _pVehiculo = 1, _pProblema = 2;
  static const _pMecanico = 3, _pConfirmar = 4;

  int _paso = _pCliente;
  bool _ocupado = false; // deshabilita botones mientras se guarda

  // ---- Paso 1: cliente -------------------------------------------------------
  Cliente? _cliente;
  bool _clienteNuevo = false;
  String _busqueda = '';
  Stream<List<ClienteResumen>>? _streamClientes;
  Stream<List<VehiculoConCliente>>? _streamCoincidencias;
  final _formCliente = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();

  // ---- Paso 2: vehículo ------------------------------------------------------
  Vehiculo? _vehiculo;
  bool _vehiculoNuevo = false;
  Stream<List<Vehiculo>>? _streamVehiculos; // depende del cliente elegido
  final _formVehiculo = GlobalKey<FormState>();
  final _camposVehiculo = CamposVehiculo();

  // ---- Paso 3: problema y kilometraje ----------------------------------------
  final _formProblema = GlobalKey<FormState>();
  final _problema = TextEditingController();
  final _km = TextEditingController();

  // ---- Paso 4: mecánico ------------------------------------------------------
  int? _mecanicoId;
  String _mecanicoNombre = '';
  late final Stream<List<CargaMecanico>> _carga = repo.watchCargaMecanicos();

  @override
  void initState() {
    super.initState();
    // Datos precargados (no se usa context aquí: solo los parámetros).
    _cliente = widget.cliente;
    if (_cliente != null) _paso = _pVehiculo;
    final v = widget.vehiculo;
    if (_cliente != null && v != null) {
      _vehiculo = v;
      _km.text = '${v.kilometraje}';
      _paso = _pProblema;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _telefono, _direccion, _problema, _km]) {
      c.dispose();
    }
    _camposVehiculo.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Lógica del asistente
  // ===========================================================================

  void _elegirCliente(Cliente c) {
    setState(() {
      // Si cambia de cliente, el vehículo elegido deja de ser válido.
      if (_cliente?.id != c.id) _vehiculo = null;
      _cliente = c;
      _streamVehiculos = null;
    });
  }

  void _elegirVehiculo(Vehiculo v) {
    setState(() {
      _vehiculo = v;
      _km.text = '${v.kilometraje}'; // kilometraje precargado
    });
  }

  /// Atajo del paso 1: se eligió directamente un vehículo de la búsqueda.
  Future<void> _elegirCoincidencia(VehiculoConCliente vc) async {
    final c = await repo.watchCliente(vc.vehiculo.clienteId).first;
    if (!mounted || c == null) return;
    _elegirCliente(c);
    _elegirVehiculo(vc.vehiculo);
    setState(() => _paso = _pProblema);
  }

  void _buscar(String texto) {
    setState(() {
      _busqueda = texto;
      _streamClientes = null; // se recrean con el nuevo texto en build
      _streamCoincidencias = null;
    });
  }

  /// Valida el paso actual y, si todo está bien, pasa al siguiente.
  Future<void> _continuar() async {
    setState(() => _ocupado = true);
    try {
      switch (_paso) {
        case _pCliente:
          if (_clienteNuevo) {
            if (!_formCliente.currentState!.validate()) break;
            final id = await repo.crearCliente(
                nombre: _nombre.text,
                telefono: _telefono.text,
                direccion: _direccion.text);
            final c = await repo.watchCliente(id).first;
            if (c == null) break;
            _elegirCliente(c);
            _clienteNuevo = false;
          }
          if (_cliente == null) {
            throw const ReglaNegocioException(
                'Elija un cliente de la lista o registre uno nuevo.');
          }
          _paso = _pVehiculo;
        case _pVehiculo:
          if (_vehiculoNuevo) {
            if (!_formVehiculo.currentState!.validate()) break;
            final d = _camposVehiculo.leer();
            final id = await repo.crearVehiculo(
              clienteId: _cliente!.id,
              matricula: d.matricula,
              marca: d.marca,
              modelo: d.modelo,
              anio: d.anio,
              kilometraje: d.kilometraje,
            );
            final v = await repo.watchVehiculo(id).first;
            if (v == null) break;
            _elegirVehiculo(v);
            _vehiculoNuevo = false;
          }
          if (_vehiculo == null) {
            throw const ReglaNegocioException(
                'Elija uno de los vehículos o registre uno nuevo.');
          }
          _paso = _pProblema;
        case _pProblema:
          if (!_formProblema.currentState!.validate()) break;
          _paso = _pMecanico;
        case _pMecanico:
          if (_mecanicoId == null) {
            throw const ReglaNegocioException('Elija el mecánico responsable.');
          }
          _paso = _pConfirmar;
        case _pConfirmar:
          await _crearOrden();
          return; // la pantalla se reemplaza por el detalle
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _crearOrden() async {
    final id = await repo.crearOrden(
      vehiculoId: _vehiculo!.id,
      mecanicoId: _mecanicoId!,
      problema: _problema.text,
      kilometraje: leerEntero(_km.text) ?? 0,
    );
    if (!mounted) return;
    mostrarExito(context, 'Orden #$id registrada');
    // pushReplacement: al volver desde el detalle no se regresa al asistente.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DetalleOrdenPantalla(ordenId: id)),
    );
  }

  void _atras() {
    if (_paso > 0) setState(() => _paso--);
  }

  // ===========================================================================
  // Interfaz
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    StepState estadoPaso(int i) =>
        i < _paso ? StepState.complete : StepState.indexed;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden')),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _paso,
        onStepContinue: _ocupado ? null : _continuar,
        onStepCancel: _ocupado ? null : _atras,
        // Solo se puede volver (tocando el título) a pasos ya completados.
        onStepTapped: (i) {
          if (i < _paso && !_ocupado) setState(() => _paso = i);
        },
        controlsBuilder: _controles,
        steps: [
          Step(
            title: const Text('Cliente'),
            subtitle: _cliente == null ? null : Text(_cliente!.nombre),
            isActive: _paso >= _pCliente,
            state: estadoPaso(_pCliente),
            content: _pasoCliente(),
          ),
          Step(
            title: const Text('Vehículo'),
            subtitle: _vehiculo == null
                ? null
                : Text('${_vehiculo!.matricula} · ${_vehiculo!.marca}'),
            isActive: _paso >= _pVehiculo,
            state: estadoPaso(_pVehiculo),
            content: _pasoVehiculo(),
          ),
          Step(
            title: const Text('Problema y kilometraje'),
            isActive: _paso >= _pProblema,
            state: estadoPaso(_pProblema),
            content: _pasoProblema(),
          ),
          Step(
            title: const Text('Mecánico'),
            subtitle: _mecanicoId == null ? null : Text(_mecanicoNombre),
            isActive: _paso >= _pMecanico,
            state: estadoPaso(_pMecanico),
            content: _pasoMecanico(),
          ),
          Step(
            title: const Text('Confirmar'),
            isActive: _paso >= _pConfirmar,
            state: estadoPaso(_pConfirmar),
            content: _pasoConfirmar(),
          ),
        ],
      ),
    );
  }

  /// Botones de cada paso (sustituyen a los de Stepper por defecto).
  Widget _controles(BuildContext context, ControlsDetails d) {
    final String texto;
    if (d.stepIndex == _pConfirmar) {
      texto = 'Crear orden';
    } else if ((d.stepIndex == _pCliente && _clienteNuevo) ||
        (d.stepIndex == _pVehiculo && _vehiculoNuevo)) {
      texto = 'Guardar y continuar';
    } else {
      texto = 'Continuar';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      // Wrap en vez de Row: en pantallas estrechas (360 dp) el contenido del
      // Stepper mide ~270 dp y "Guardar y continuar" + "Atrás" no caben en una
      // fila (desborde); Wrap pasa "Atrás" a la línea siguiente.
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: d.onStepContinue,
            icon: _ocupado
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(d.stepIndex == _pConfirmar
                    ? Icons.check
                    : Icons.arrow_forward),
            label: Text(texto),
          ),
          if (d.stepIndex > 0)
            TextButton(onPressed: d.onStepCancel, child: const Text('Atrás')),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Paso 1: cliente
  // ---------------------------------------------------------------------------
  Widget _pasoCliente() {
    if (_clienteNuevo) {
      return Form(
        key: _formCliente,
        child: Column(
          children: [
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration:
                  decoracionCampo('Nombre completo', icono: Icons.person_outline),
              validator: validarObligatorio,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: decoracionCampo('Teléfono', icono: Icons.phone_outlined),
              validator: validarTelefono,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _direccion,
              decoration: decoracionCampo('Dirección (opcional)',
                  icono: Icons.home_outlined),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Buscar un cliente existente'),
                onPressed: () => setState(() => _clienteNuevo = false),
              ),
            ),
          ],
        ),
      );
    }

    // Streams guardados: se recrean solo si cambió el texto buscado.
    _streamClientes ??= repo.watchClientes(busqueda: _busqueda);
    if (_busqueda.trim().isNotEmpty) {
      _streamCoincidencias ??= repo.watchVehiculos(busqueda: _busqueda);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CampoBusqueda(
            pista: 'Nombre, teléfono o matrícula', onCambio: _buscar),
        const SizedBox(height: 8),
        StreamBuilder<List<ClienteResumen>>(
          stream: _streamClientes,
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            final lista = snap.data!;
            if (lista.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No se encontró ningún cliente.',
                    style: TextStyle(color: Paleta.textoSecundario)),
              );
            }
            // Se muestran pocos para no alargar el paso; el resto con búsqueda.
            final visibles = lista.take(6).toList();
            return Column(
              children: [
                for (final r in visibles)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    selected: _cliente?.id == r.cliente.id,
                    selectedTileColor: Paleta.primarioSuave,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadioCampo)),
                    leading: CircleAvatar(
                      backgroundColor: Paleta.primarioSuave,
                      child: Text(iniciales(r.cliente.nombre),
                          style: const TextStyle(color: Paleta.primarioOscuro)),
                    ),
                    title: Text(r.cliente.nombre),
                    subtitle: Text('${r.cliente.telefono} · '
                        '${r.vehiculos} vehículo(s)'),
                    trailing: _cliente?.id == r.cliente.id
                        ? const Icon(Icons.check_circle, color: Paleta.primario)
                        : null,
                    onTap: () => _elegirCliente(r.cliente),
                  ),
                if (lista.length > visibles.length)
                  Text('y ${lista.length - visibles.length} más: escriba para '
                      'filtrar.',
                      style: const TextStyle(color: Paleta.textoSecundario)),
              ],
            );
          },
        ),
        // Vehículos que coinciden con el texto (búsqueda por matrícula).
        if (_busqueda.trim().isNotEmpty)
          StreamBuilder<List<VehiculoConCliente>>(
            stream: _streamCoincidencias,
            builder: (context, snap) {
              final lista = snap.data ?? const <VehiculoConCliente>[];
              if (lista.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
                    child: Text('Vehículos que coinciden',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  for (final vc in lista.take(4))
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: const Icon(Icons.directions_car_outlined),
                      title: Text('${vc.vehiculo.matricula} · '
                          '${vc.vehiculo.marca} ${vc.vehiculo.modelo}'),
                      subtitle: Text('Dueño: ${vc.clienteNombre}'),
                      trailing: const Icon(Icons.fast_forward_outlined),
                      onTap: () => _elegirCoincidencia(vc),
                    ),
                ],
              );
            },
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Cliente nuevo'),
          onPressed: () => setState(() {
            _clienteNuevo = true;
            _busqueda = '';
            _streamClientes = null;
            _streamCoincidencias = null;
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Paso 2: vehículo
  // ---------------------------------------------------------------------------
  Widget _pasoVehiculo() {
    final cliente = _cliente;
    // El Stepper construye TODOS los pasos (los ocultos con alto 0), por eso
    // hay que contemplar que todavía no haya cliente.
    if (cliente == null) {
      return const Text('Primero elija el cliente.');
    }
    if (_vehiculoNuevo) {
      return Form(
        key: _formVehiculo,
        child: Column(
          children: [
            for (final campo in _camposVehiculo.construir())
              Padding(padding: const EdgeInsets.only(bottom: 12), child: campo),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.list),
                label: const Text('Elegir uno de sus vehículos'),
                onPressed: () => setState(() => _vehiculoNuevo = false),
              ),
            ),
          ],
        ),
      );
    }

    _streamVehiculos ??= repo.watchVehiculosDeCliente(cliente.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<Vehiculo>>(
          stream: _streamVehiculos,
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            final lista = snap.data!;
            if (lista.isEmpty) {
              return Text('${cliente.nombre} no tiene vehículos registrados.',
                  style: const TextStyle(color: Paleta.textoSecundario));
            }
            return Column(
              children: [
                for (final v in lista)
                  Tarjeta(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    color: _vehiculo?.id == v.id
                        ? Paleta.primarioSuave
                        : Paleta.tarjeta,
                    colorBorde: _vehiculo?.id == v.id
                        ? Paleta.primario
                        : Paleta.borde,
                    onTap: () => _elegirVehiculo(v),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_outlined,
                            color: Paleta.primarioOscuro),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.matricula,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text('${v.marca} ${v.modelo} (${v.anio}) · '
                                  '${numero(v.kilometraje)} km',
                                  style: const TextStyle(
                                      color: Paleta.textoSecundario)),
                            ],
                          ),
                        ),
                        if (_vehiculo?.id == v.id)
                          const Icon(Icons.check_circle, color: Paleta.primario),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Registrar vehículo nuevo'),
          onPressed: () => setState(() => _vehiculoNuevo = true),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Paso 3: problema y kilometraje
  // ---------------------------------------------------------------------------
  Widget _pasoProblema() {
    final ultimo = _vehiculo?.kilometraje;
    return Form(
      key: _formProblema,
      child: Column(
        children: [
          TextFormField(
            controller: _problema,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: decoracionCampo('¿Qué problema reporta el cliente?',
                icono: Icons.report_problem_outlined,
                pista: 'Ruido al frenar, no arranca...'),
            validator: validarObligatorio,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _km,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: decoracionCampo('Kilometraje de entrada',
                icono: Icons.speed,
                sufijo: 'km',
                ayuda: ultimo == null
                    ? null
                    : 'Último registrado: ${numero(ultimo)} km'),
            validator: validarEnteroNoNegativo,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Paso 4: mecánico
  // ---------------------------------------------------------------------------
  Widget _pasoMecanico() {
    return StreamBuilder<List<CargaMecanico>>(
      stream: _carga,
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final activos = snap.data!.where((c) => c.mecanico.activo).toList();
        if (activos.isEmpty) {
          return const Text('No hay mecánicos activos. Actívelos en Ajustes.');
        }
        // El de menor carga se sugiere con una etiqueta.
        final menor =
            activos.reduce((a, b) => b.abiertas < a.abiertas ? b : a);
        return Column(
          children: [
            for (final c in activos)
              RadioListTile<int>(
                value: c.mecanico.id,
                groupValue: _mecanicoId,
                onChanged: (id) => setState(() {
                  _mecanicoId = id;
                  _mecanicoNombre = c.mecanico.nombre;
                }),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadioCampo)),
                title: Row(
                  children: [
                    Flexible(child: Text(c.mecanico.nombre)),
                    if (identical(c, menor)) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text('Sugerido',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF166534))),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  c.abiertas == 0
                      ? 'Libre, sin órdenes abiertas'
                      : '${c.abiertas} abiertas: ${c.enDiagnostico} por '
                          'diagnosticar, ${c.enReparacion} en reparación',
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Paso 5: confirmar
  // ---------------------------------------------------------------------------
  Widget _pasoConfirmar() {
    final c = _cliente;
    final v = _vehiculo;
    if (c == null || v == null) return const SizedBox.shrink();
    Widget fila(IconData icono, String etiqueta, String valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 18, color: Paleta.primarioOscuro),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(etiqueta,
                    style: const TextStyle(color: Paleta.textoSecundario)),
              ),
              Expanded(
                child: Text(valor,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );
    return Tarjeta(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          fila(Icons.person_outline, 'Cliente', '${c.nombre} (${c.telefono})'),
          fila(Icons.directions_car_outlined, 'Vehículo',
              '${v.matricula} · ${v.marca} ${v.modelo} (${v.anio})'),
          fila(Icons.speed, 'Kilometraje',
              '${numero(leerEntero(_km.text) ?? 0)} km'),
          fila(Icons.report_problem_outlined, 'Problema', _problema.text.trim()),
          fila(Icons.engineering_outlined, 'Mecánico', _mecanicoNombre),
          fila(Icons.schedule, 'Entrada', fechaHora(DateTime.now())),
        ],
      ),
    );
  }
}
