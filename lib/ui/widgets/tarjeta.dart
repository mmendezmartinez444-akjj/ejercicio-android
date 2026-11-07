// =============================================================================
// tarjeta.dart
// Piezas visuales básicas reutilizadas en todas las pantallas:
//   - Tarjeta: contenedor blanco SIN elevación, con borde sutil y radio 20.
//     Sustituye a Card para no depender de cardTheme (cambia entre versiones).
//   - TituloSeccion: encabezado de sección con icono y acción opcional.
//   - BarraNivel: LinearProgressIndicator redondeado (stock, carga).
// =============================================================================
import 'package:flutter/material.dart';

import '../tema.dart';

class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color color;
  final Color colorBorde;

  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.color = Paleta.tarjeta,
    this.colorBorde = Paleta.borde,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(kRadio);
    // Material + InkWell: así el "ripple" al tocar respeta los bordes
    // redondeados. El borde se dibuja con la forma del Material.
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(color: colorBorde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Encabezado de una sección ("Trabajos", "Deudores"...).
class TituloSeccion extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final Widget? accion;

  const TituloSeccion(this.texto, {super.key, this.icono, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Row(
        children: [
          if (icono != null) ...[
            Icon(icono, size: 20, color: Paleta.primarioOscuro),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

/// Barra de nivel redondeada (valor entre 0 y 1).
class BarraNivel extends StatelessWidget {
  final double valor;
  final Color color;
  final double alto;

  const BarraNivel({
    super.key,
    required this.valor,
    this.color = Paleta.primario,
    this.alto = 8,
  });

  @override
  Widget build(BuildContext context) {
    // ClipRRect redondea la barra (LinearProgressIndicator.borderRadius no
    // existe en todas las versiones de Flutter).
    return ClipRRect(
      borderRadius: BorderRadius.circular(alto),
      child: LinearProgressIndicator(
        value: valor.clamp(0.0, 1.0),
        minHeight: alto,
        color: color,
        backgroundColor: Paleta.borde,
      ),
    );
  }
}
