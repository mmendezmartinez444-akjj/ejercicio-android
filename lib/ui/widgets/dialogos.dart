// =============================================================================
// dialogos.dart
// Formularios en AlertDialog para crear/editar datos maestros:
//   - DialogoFormulario: "esqueleto" común (Form + validación + botón Guardar
//     con indicador de progreso + error de negocio mostrado DENTRO del diálogo).
//   - DialogoCliente, DialogoVehiculo, DialogoRepuesto, DialogoCantidad,
//     DialogoTexto: cada uno es dueño de sus TextEditingController.
//
// Patrón: el diálogo recibe una función `guardar` que llama al repositorio.
// Si el repositorio lanza ReglaNegocioException (p. ej. matrícula repetida),
// el diálogo NO se cierra y muestra el mensaje para que se corrija el dato.
// Si todo sale bien, se cierra devolviendo `true` con Navigator.pop.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/base_datos.dart';
import '../../utils/formato.dart';
import '../tema.dart';
import 'mensajes.dart';

/// Muestra un diálogo y devuelve true si se guardó.
Future<bool> abrirDialogo(BuildContext context, Widget dialogo) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false, // evita perder lo escrito por un toque fuera
    builder: (_) => dialogo,
  );
  return r ?? false;
}

// -----------------------------------------------------------------------------
// Esqueleto común
// -----------------------------------------------------------------------------
class DialogoFormulario extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> campos;
  final GlobalKey<FormState> formKey;
  final Future<void> Function() guardar;
  final String textoGuardar;

  const DialogoFormulario({
    super.key,
    required this.titulo,
    required this.icono,
    required this.campos,
    required this.formKey,
    required this.guardar,
    this.textoGuardar = 'Guardar',
  });

  @override
  State<DialogoFormulario> createState() => _DialogoFormularioState();
}

class _DialogoFormularioState extends State<DialogoFormulario> {
  bool _guardando = false;
  String? _error;

  Future<void> _enviar() async {
    // 1) Validación de cada campo (validator de los TextFormField).
    if (!(widget.formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    // 2) Reglas de negocio del repositorio.
    try {
      await widget.guardar();
      if (!mounted) return; // el State pudo destruirse durante el await
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = textoDeError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(widget.icono, color: Paleta.primario),
      title: Text(widget.titulo),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: widget.formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Separación uniforme entre campos.
                for (final c in widget.campos)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(kRadioCampo),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: Paleta.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _enviar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.textoGuardar),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Validadores reutilizables (devuelven null si el valor es correcto).
// -----------------------------------------------------------------------------
String? validarObligatorio(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

String? validarTelefono(String? v) {
  if (v == null || v.trim().isEmpty) return 'Escriba el teléfono';
  if (!RegExp(r'^[0-9+\-\s]{6,20}$').hasMatch(v.trim())) {
    return 'Solo dígitos, mínimo 6';
  }
  return null;
}

String? validarEnteroNoNegativo(String? v) {
  final n = leerEntero(v ?? '');
  if (n == null) return 'Escriba un número';
  if (n < 0) return 'No puede ser negativo';
  return null;
}

String? validarDineroNoNegativo(String? v) {
  final n = leerDinero(v ?? '');
  if (n == null) return 'Escriba un importe';
  if (n < 0) return 'No puede ser negativo';
  return null;
}

// -----------------------------------------------------------------------------
// Cliente
// -----------------------------------------------------------------------------
/// Datos escritos en el formulario de cliente.
class DatosCliente {
  final String nombre;
  final String telefono;
  final String? direccion;
  const DatosCliente(this.nombre, this.telefono, this.direccion);
}

class DialogoCliente extends StatefulWidget {
  final Cliente? cliente; // null = nuevo
  final Future<void> Function(DatosCliente datos) guardar;

  const DialogoCliente({super.key, this.cliente, required this.guardar});

  @override
  State<DialogoCliente> createState() => _DialogoClienteState();
}

class _DialogoClienteState extends State<DialogoCliente> {
  final _formKey = GlobalKey<FormState>();
  // Los controladores se inicializan con los datos actuales si se edita.
  late final _nombre = TextEditingController(text: widget.cliente?.nombre);
  late final _telefono = TextEditingController(text: widget.cliente?.telefono);
  late final _direccion = TextEditingController(text: widget.cliente?.direccion);

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente',
      icono: Icons.person_add_alt_1_outlined,
      formKey: _formKey,
      guardar: () => widget.guardar(
          DatosCliente(_nombre.text, _telefono.text, _direccion.text)),
      campos: [
        TextFormField(
          controller: _nombre,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: decoracionCampo('Nombre completo', icono: Icons.person_outline),
          validator: validarObligatorio,
        ),
        TextFormField(
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: decoracionCampo('Teléfono', icono: Icons.phone_outlined),
          validator: validarTelefono,
        ),
        TextFormField(
          controller: _direccion,
          decoration: decoracionCampo('Dirección (opcional)',
              icono: Icons.home_outlined),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Vehículo
// -----------------------------------------------------------------------------
class DatosVehiculo {
  final String matricula;
  final String marca;
  final String modelo;
  final int anio;
  final int kilometraje;
  const DatosVehiculo(
      this.matricula, this.marca, this.modelo, this.anio, this.kilometraje);
}

/// Campos del vehículo. Se usan en el diálogo y también "en línea" dentro
/// del asistente de nueva orden (por eso es una clase aparte).
class CamposVehiculo {
  final matricula = TextEditingController();
  final marca = TextEditingController();
  final modelo = TextEditingController();
  final anio = TextEditingController();
  final kilometraje = TextEditingController();

  void cargar(Vehiculo v) {
    matricula.text = v.matricula;
    marca.text = v.marca;
    modelo.text = v.modelo;
    anio.text = '${v.anio}';
    kilometraje.text = '${v.kilometraje}';
  }

  DatosVehiculo leer() => DatosVehiculo(
        matricula.text,
        marca.text,
        modelo.text,
        leerEntero(anio.text) ?? 0,
        leerEntero(kilometraje.text) ?? 0,
      );

  void dispose() {
    matricula.dispose();
    marca.dispose();
    modelo.dispose();
    anio.dispose();
    kilometraje.dispose();
  }

  /// Lista de TextFormField lista para poner en una Column.
  List<Widget> construir() {
    final maxAnio = DateTime.now().year + 1;
    return [
      TextFormField(
        controller: matricula,
        textCapitalization: TextCapitalization.characters,
        decoration: decoracionCampo('Matrícula',
            icono: Icons.pin_outlined, pista: 'P123456'),
        validator: validarObligatorio,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: marca,
              textCapitalization: TextCapitalization.words,
              decoration: decoracionCampo('Marca'),
              validator: validarObligatorio,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: modelo,
              textCapitalization: TextCapitalization.words,
              decoration: decoracionCampo('Modelo'),
              validator: validarObligatorio,
            ),
          ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: anio,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: decoracionCampo('Año'),
              validator: (v) {
                final n = leerEntero(v ?? '');
                if (n == null) return 'Escriba el año';
                if (n < 1900 || n > maxAnio) return '1900 a $maxAnio';
                return null;
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: kilometraje,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: decoracionCampo('Kilometraje', sufijo: 'km'),
              validator: validarEnteroNoNegativo,
            ),
          ),
        ],
      ),
    ];
  }
}

class DialogoVehiculo extends StatefulWidget {
  final Vehiculo? vehiculo; // null = nuevo
  final Future<void> Function(DatosVehiculo datos) guardar;

  const DialogoVehiculo({super.key, this.vehiculo, required this.guardar});

  @override
  State<DialogoVehiculo> createState() => _DialogoVehiculoState();
}

class _DialogoVehiculoState extends State<DialogoVehiculo> {
  final _formKey = GlobalKey<FormState>();
  final _campos = CamposVehiculo();

  @override
  void initState() {
    super.initState();
    final v = widget.vehiculo;
    if (v != null) _campos.cargar(v); // modo edición: precarga los datos
  }

  @override
  void dispose() {
    _campos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: widget.vehiculo == null ? 'Nuevo vehículo' : 'Editar vehículo',
      icono: Icons.directions_car_outlined,
      formKey: _formKey,
      guardar: () => widget.guardar(_campos.leer()),
      campos: _campos.construir(),
    );
  }
}

// -----------------------------------------------------------------------------
// Repuesto (inventario)
// -----------------------------------------------------------------------------
class DatosRepuesto {
  final String codigo;
  final String nombre;
  final double precio;
  final int existencias;
  final int minimo;
  const DatosRepuesto(
      this.codigo, this.nombre, this.precio, this.existencias, this.minimo);
}

class DialogoRepuesto extends StatefulWidget {
  final Repuesto? repuesto; // null = nuevo
  final Future<void> Function(DatosRepuesto datos) guardar;

  const DialogoRepuesto({super.key, this.repuesto, required this.guardar});

  @override
  State<DialogoRepuesto> createState() => _DialogoRepuestoState();
}

class _DialogoRepuestoState extends State<DialogoRepuesto> {
  final _formKey = GlobalKey<FormState>();
  late final _codigo = TextEditingController(text: widget.repuesto?.codigo);
  late final _nombre = TextEditingController(text: widget.repuesto?.nombre);
  late final _precio = TextEditingController(
      text: widget.repuesto?.precioVenta.toStringAsFixed(2));
  late final _existencias =
      TextEditingController(text: '${widget.repuesto?.existencias ?? 0}');
  late final _minimo =
      TextEditingController(text: '${widget.repuesto?.stockMinimo ?? 3}');

  @override
  void dispose() {
    _codigo.dispose();
    _nombre.dispose();
    _precio.dispose();
    _existencias.dispose();
    _minimo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: widget.repuesto == null ? 'Nuevo repuesto' : 'Editar repuesto',
      icono: Icons.inventory_2_outlined,
      formKey: _formKey,
      guardar: () => widget.guardar(DatosRepuesto(
        _codigo.text,
        _nombre.text,
        leerDinero(_precio.text) ?? 0,
        leerEntero(_existencias.text) ?? 0,
        leerEntero(_minimo.text) ?? 0,
      )),
      campos: [
        TextFormField(
          controller: _codigo,
          textCapitalization: TextCapitalization.characters,
          decoration: decoracionCampo('Código', icono: Icons.qr_code_2),
          validator: validarObligatorio,
        ),
        TextFormField(
          controller: _nombre,
          decoration: decoracionCampo('Nombre', icono: Icons.label_outline),
          validator: validarObligatorio,
        ),
        TextFormField(
          controller: _precio,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: decoracionCampo('Precio de venta',
              icono: Icons.sell_outlined, sufijo: kMoneda),
          validator: validarDineroNoNegativo,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _existencias,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: decoracionCampo('Existencias'),
                validator: validarEnteroNoNegativo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _minimo,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: decoracionCampo('Stock mínimo'),
                validator: validarEnteroNoNegativo,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Cantidad (reabastecer)
// -----------------------------------------------------------------------------
class DialogoCantidad extends StatefulWidget {
  final String titulo;
  final String detalle;
  final Future<void> Function(int cantidad) guardar;

  const DialogoCantidad({
    super.key,
    required this.titulo,
    required this.detalle,
    required this.guardar,
  });

  @override
  State<DialogoCantidad> createState() => _DialogoCantidadState();
}

class _DialogoCantidadState extends State<DialogoCantidad> {
  final _formKey = GlobalKey<FormState>();
  final _cantidad = TextEditingController();

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: widget.titulo,
      icono: Icons.add_shopping_cart,
      formKey: _formKey,
      textoGuardar: 'Añadir',
      guardar: () => widget.guardar(leerEntero(_cantidad.text) ?? 0),
      campos: [
        Text(widget.detalle,
            style: const TextStyle(color: Paleta.textoSecundario)),
        TextFormField(
          controller: _cantidad,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: decoracionCampo('Unidades compradas',
              icono: Icons.add_box_outlined),
          validator: (v) {
            final n = leerEntero(v ?? '');
            if (n == null || n <= 0) return 'Debe ser mayor que cero';
            return null;
          },
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Texto simple (nombre del mecánico, problema de la orden)
// -----------------------------------------------------------------------------
class DialogoTexto extends StatefulWidget {
  final String titulo;
  final String etiqueta;
  final IconData icono;
  final String? inicial;
  final int lineas;
  final Future<void> Function(String texto) guardar;

  const DialogoTexto({
    super.key,
    required this.titulo,
    required this.etiqueta,
    required this.icono,
    required this.guardar,
    this.inicial,
    this.lineas = 1,
  });

  @override
  State<DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<DialogoTexto> {
  final _formKey = GlobalKey<FormState>();
  late final _texto = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DialogoFormulario(
      titulo: widget.titulo,
      icono: widget.icono,
      formKey: _formKey,
      guardar: () => widget.guardar(_texto.text),
      campos: [
        TextFormField(
          controller: _texto,
          autofocus: true,
          minLines: 1,
          maxLines: widget.lineas,
          textCapitalization: TextCapitalization.sentences,
          decoration: decoracionCampo(widget.etiqueta),
          validator: validarObligatorio,
        ),
      ],
    );
  }
}
