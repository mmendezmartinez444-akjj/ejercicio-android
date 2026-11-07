// =============================================================================
// pildora_estado.dart
// "Píldora" pastel con el estado de la orden (fondo claro + texto oscuro).
// Los colores salen de la extensión EstadoOrdenUI de tema.dart, así cada
// estado se ve igual en todas las pantallas.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/modelos.dart';
import '../../data/tablas.dart';
import '../tema.dart';

class PildoraEstado extends StatelessWidget {
  final EstadoOrden estado;

  /// Texto alternativo (p. ej. "3 recibidas" en el inicio).
  final String? texto;

  const PildoraEstado(this.estado, {super.key, this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estado.colorFondo,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 14, color: estado.colorTexto),
          const SizedBox(width: 4),
          Text(
            texto ?? estado.etiqueta, // etiqueta viene de EstadoOrdenX (núcleo)
            style: TextStyle(
              color: estado.colorTexto,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
