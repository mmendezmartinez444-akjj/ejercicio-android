// =============================================================================
// tarjeta_orden.dart
// Tarjeta resumen de una orden para las listas (Órdenes, historial del
// cliente y del vehículo, reportes). Muestra número, píldora de estado,
// vehículo, cliente, mecánico, antigüedad y el saldo pendiente.
// Al tocarla abre el detalle de la orden con Navigator.push.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/modelos.dart';
import '../../utils/formato.dart';
import '../pantallas/detalle_orden_pantalla.dart';
import '../tema.dart';
import 'pildora_estado.dart';
import 'tarjeta.dart';

class TarjetaOrden extends StatelessWidget {
  final OrdenResumen orden;

  /// En el historial de un vehículo no hace falta repetir la matrícula.
  final bool mostrarVehiculo;

  const TarjetaOrden(this.orden, {super.key, this.mostrarVehiculo = true});

  @override
  Widget build(BuildContext context) {
    final o = orden;
    final estilos = Theme.of(context).textTheme;
    return Tarjeta(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalleOrdenPantalla(ordenId: o.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: número de orden + estado.
          Row(
            children: [
              Text('Orden #${o.id}', style: estilos.titleMedium),
              const Spacer(),
              PildoraEstado(o.estado),
            ],
          ),
          const SizedBox(height: 8),
          if (mostrarVehiculo)
            Text('${o.matricula} · ${o.vehiculoTexto}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(o.problema,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Paleta.textoSecundario)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: Paleta.textoSecundario),
              const SizedBox(width: 4),
              Expanded(
                child: Text(o.clienteNombre,
                    overflow: TextOverflow.ellipsis, style: estilos.bodySmall),
              ),
              const Icon(Icons.engineering_outlined,
                  size: 16, color: Paleta.textoSecundario),
              const SizedBox(width: 4),
              // Ancho máximo: un nombre largo de mecánico (hasta 80
              // caracteres) desbordaría la fila.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(o.mecanicoNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: estilos.bodySmall),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Text(haceCuanto(o.fechaEntrada), style: estilos.bodySmall),
              const Spacer(),
              _Saldo(o),
            ],
          ),
        ],
      ),
    );
  }
}

/// Texto del saldo con color según la situación de pago.
class _Saldo extends StatelessWidget {
  final OrdenResumen o;
  const _Saldo(this.o);

  @override
  Widget build(BuildContext context) {
    if (o.total <= 0) {
      return const Text('Sin cargos aún',
          style: TextStyle(color: Paleta.textoSecundario));
    }
    if (o.pagadaCompleta) {
      return Text('Pagada · ${dinero(o.total)}',
          style: const TextStyle(
              color: Paleta.exito, fontWeight: FontWeight.w600));
    }
    return Text('Saldo ${dinero(o.saldo)}',
        style: const TextStyle(color: Paleta.acento, fontWeight: FontWeight.w700));
  }
}
