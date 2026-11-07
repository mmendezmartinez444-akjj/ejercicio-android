// =============================================================================
// ticket_totales.dart
// "Ticket" de totales con aspecto de recibo impreso: líneas punteadas,
// importes alineados a la derecha y el saldo destacado al final.
//   Total = mano de obra + repuestos;   Saldo = total - pagado.
// Los importes ya vienen calculados en OrdenResumen (núcleo de datos).
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/modelos.dart';
import '../../utils/formato.dart';
import '../tema.dart';

class TicketTotales extends StatelessWidget {
  final OrdenResumen orden;
  const TicketTotales(this.orden, {super.key});

  @override
  Widget build(BuildContext context) {
    final o = orden;
    final saldoPendiente = o.saldo > 0.009;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Paleta.tarjeta,
        borderRadius: BorderRadius.circular(kRadio),
        border: Border.all(color: Paleta.borde),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, color: Paleta.primarioOscuro),
          const SizedBox(height: 4),
          Text('TALLER EL PISTÓN · ORDEN #${o.id}',
              style: const TextStyle(
                  letterSpacing: 1.2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Paleta.textoSecundario)),
          const _LineaPunteada(),
          _Fila('Mano de obra', o.manoObra),
          _Fila('Repuestos', o.totalRepuestos),
          const _LineaPunteada(),
          _Fila('TOTAL', o.total, negrita: true),
          _Fila('Pagado', -o.pagado, color: Paleta.exito),
          const _LineaPunteada(),
          _Fila(
            saldoPendiente ? 'SALDO PENDIENTE' : 'SALDO',
            o.saldo,
            negrita: true,
            grande: true,
            color: saldoPendiente ? Paleta.acento : Paleta.exito,
          ),
          if (!saldoPendiente && o.total > 0)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('¡Pagado por completo! Gracias.',
                  style: TextStyle(color: Paleta.exito)),
            ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  final String etiqueta;
  final double valor;
  final bool negrita;
  final bool grande;
  final Color? color;

  const _Fila(this.etiqueta, this.valor,
      {this.negrita = false, this.grande = false, this.color});

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      fontWeight: negrita ? FontWeight.w700 : FontWeight.w400,
      fontSize: grande ? 18 : 14,
      color: color ?? Paleta.texto,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: estilo)),
          Text(dinero(valor), style: estilo),
        ],
      ),
    );
  }
}

/// Línea discontinua dibujada con pequeños rectángulos (como un recibo).
/// LayoutBuilder da el ancho disponible para calcular cuántos guiones caben.
class _LineaPunteada extends StatelessWidget {
  const _LineaPunteada();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(builder: (context, restricciones) {
        final cantidad = (restricciones.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            cantidad,
            (_) => Container(width: 4, height: 1.5, color: Paleta.borde),
          ),
        );
      }),
    );
  }
}
