// =============================================================================
// linea_tiempo_estados.dart
// Línea de tiempo VERTICAL con el flujo de estados de una orden:
//   recibida -> diagnóstico -> reparación -> lista -> entregada.
// Los pasos ya superados se marcan con un check verde, el actual se resalta
// con su color de estado y los futuros quedan en gris. Si la orden está
// cancelada se muestra un aviso en lugar del flujo.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/modelos.dart';
import '../../data/tablas.dart';
import '../../utils/formato.dart';
import '../tema.dart';

class LineaTiempoEstados extends StatelessWidget {
  final EstadoOrden estado;
  final DateTime fechaEntrada;
  final DateTime? fechaEntrega;

  const LineaTiempoEstados({
    super.key,
    required this.estado,
    required this.fechaEntrada,
    this.fechaEntrega,
  });

  @override
  Widget build(BuildContext context) {
    if (estado == EstadoOrden.cancelada) {
      return Row(
        children: [
          Icon(Icons.block, color: estado.colorTexto),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Orden cancelada. Los repuestos volvieron al inventario.',
              style: TextStyle(color: estado.colorTexto),
            ),
          ),
        ],
      );
    }

    final pasos = EstadoOrdenX.flujo; // lista del núcleo (sin "cancelada")
    final actual = pasos.indexOf(estado);
    return Column(
      children: [
        for (var i = 0; i < pasos.length; i++)
          _Paso(
            estado: pasos[i],
            completado: i < actual || estado == EstadoOrden.entregada,
            esActual: i == actual && estado != EstadoOrden.entregada,
            esUltimo: i == pasos.length - 1,
            // Fechas conocidas: la de entrada (primer paso) y la de entrega.
            detalle: i == 0
                ? fechaHora(fechaEntrada)
                : (pasos[i] == EstadoOrden.entregada && fechaEntrega != null)
                    ? fechaHora(fechaEntrega!)
                    : null,
          ),
      ],
    );
  }
}

/// Un paso de la línea: círculo + conector vertical + etiqueta.
class _Paso extends StatelessWidget {
  final EstadoOrden estado;
  final bool completado;
  final bool esActual;
  final bool esUltimo;
  final String? detalle;

  const _Paso({
    required this.estado,
    required this.completado,
    required this.esActual,
    required this.esUltimo,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final Color colorCirculo = completado
        ? Paleta.primario
        : esActual
            ? estado.colorTexto
            : Paleta.borde;
    // IntrinsicHeight permite que el conector vertical ocupe todo el alto
    // de la fila.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: esActual ? estado.colorFondo : colorCirculo,
                    shape: BoxShape.circle,
                    border: esActual
                        ? Border.all(color: estado.colorTexto, width: 2)
                        : null,
                  ),
                  child: Icon(
                    completado ? Icons.check : estado.icono,
                    size: 16,
                    color: completado
                        ? Colors.white
                        : esActual
                            ? estado.colorTexto
                            : Paleta.textoSecundario,
                  ),
                ),
                if (!esUltimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: completado ? Paleta.primario : Paleta.borde,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: esUltimo ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estado.etiqueta,
                    style: TextStyle(
                      fontWeight: esActual ? FontWeight.w700 : FontWeight.w500,
                      color: esActual || completado
                          ? Paleta.texto
                          : Paleta.textoSecundario,
                    ),
                  ),
                  if (detalle != null)
                    Text(detalle!,
                        style: const TextStyle(
                            fontSize: 12, color: Paleta.textoSecundario)),
                ],
              ),
            ),
          ),
          if (esActual)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Ahora',
                  style: TextStyle(
                      color: estado.colorTexto, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
