// =============================================================================
// mensajes.dart
// Funciones de ayuda para comunicarse con el usuario:
//   - mostrarExito / mostrarError: SnackBar flotante verde o rojo.
//   - confirmar: AlertDialog "¿Seguro?" que devuelve true/false.
//   - mostrarAvisoStock: aviso ámbar cuando un repuesto queda por agotarse.
//   - ejecutarAccion: ejecuta una operación del repositorio capturando
//     ReglaNegocioException y cualquier otro error, y muestra el resultado.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/base_datos.dart';
import '../../data/modelos.dart';
import '../tema.dart';

/// Convierte un error en un texto entendible para la recepcionista.
String textoDeError(Object e) =>
    e is ReglaNegocioException ? e.mensaje : 'Ocurrió un error: $e';

void mostrarExito(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: Paleta.primarioOscuro,
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(mensaje)),
      ]),
    ));
}

void mostrarError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: Paleta.error,
      duration: const Duration(seconds: 5),
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(textoDeError(error))),
      ]),
    ));
}

/// Pide confirmación. Devuelve true solo si el usuario pulsa "confirmar".
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Confirmar',
  bool peligroso = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(peligroso ? Icons.warning_amber_rounded : Icons.help_outline,
          color: peligroso ? Paleta.error : Paleta.primario),
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: peligroso
              ? FilledButton.styleFrom(backgroundColor: Paleta.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return r ?? false; // si se cierra tocando fuera, cuenta como "no"
}

/// Aviso visible tras usar un repuesto que quedó en el mínimo o por debajo.
Future<void> mostrarAvisoStock(BuildContext context, Repuesto r) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.inventory_2_outlined, color: Paleta.aviso, size: 36),
      title: const Text('Repuesto por agotarse'),
      content: Text(
        'Quedan ${r.existencias} de ${r.nombre}: hay que comprar.\n'
        '(Mínimo configurado: ${r.stockMinimo})',
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Paleta.aviso),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}

/// Ejecuta [accion] y muestra el resultado. Devuelve true si salió bien.
/// Tras el `await` se comprueba `context.mounted`: si el usuario salió de la
/// pantalla mientras se guardaba, el context ya no es válido.
Future<bool> ejecutarAccion(
  BuildContext context,
  Future<void> Function() accion, {
  String? exito,
}) async {
  try {
    await accion();
    if (!context.mounted) return true;
    if (exito != null) mostrarExito(context, exito);
    return true;
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
    return false;
  }
}
