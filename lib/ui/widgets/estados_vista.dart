// =============================================================================
// estados_vista.dart
// Widgets para los estados de un StreamBuilder que no son "datos listos":
//   - Cargando: indicador circular centrado mientras llega el primer dato.
//   - MensajeVacio: ilustración amable cuando una lista no tiene elementos.
//   - MensajeError: texto del error si el Stream falla.
// =============================================================================
import 'package:flutter/material.dart';

import '../tema.dart';

class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
}

class MensajeVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? detalle;

  const MensajeVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Círculo de color suave con el icono: estilo "amable".
          CircleAvatar(
            radius: 34,
            backgroundColor: Paleta.primarioSuave,
            child: Icon(icono, size: 34, color: Paleta.primarioOscuro),
          ),
          const SizedBox(height: 14),
          Text(titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          if (detalle != null) ...[
            const SizedBox(height: 6),
            Text(detalle!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Paleta.textoSecundario)),
          ],
        ],
      ),
    );
  }
}

class MensajeError extends StatelessWidget {
  final Object? error;
  const MensajeError(this.error, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('No se pudieron cargar los datos: $error',
            style: const TextStyle(color: Paleta.error)),
      );
}
