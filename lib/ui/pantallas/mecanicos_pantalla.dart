// =============================================================================
// mecanicos_pantalla.dart
// Gestión de mecánicos: listar con su carga actual, añadir, renombrar
// (tocando la tarjeta) y activar/desactivar con un Switch. Los inactivos no
// aparecen al crear órdenes, pero conservan su historial.
// Usa watchCargaMecanicos(), que devuelve cada mecánico (activo o no) con el
// número de órdenes abiertas desglosado por estado.
// =============================================================================
import 'package:flutter/material.dart';

import '../../data/modelos.dart';
import '../../data/repositorio_taller.dart';
import '../../data/taller_scope.dart';
import '../tema.dart';
import '../widgets/dialogos.dart';
import '../widgets/estados_vista.dart';
import '../widgets/mensajes.dart';
import '../widgets/tarjeta.dart';

class MecanicosPantalla extends StatefulWidget {
  const MecanicosPantalla({super.key});

  @override
  State<MecanicosPantalla> createState() => _MecanicosPantallaState();
}

class _MecanicosPantallaState extends State<MecanicosPantalla> {
  late final RepositorioTaller repo = TallerScope.of(context);
  late final Stream<List<CargaMecanico>> _carga = repo.watchCargaMecanicos();

  Future<void> _nuevo() async {
    final ok = await abrirDialogo(
      context,
      DialogoTexto(
        titulo: 'Nuevo mecánico',
        etiqueta: 'Nombre',
        icono: Icons.engineering_outlined,
        guardar: (nombre) => repo.guardarMecanico(nombre: nombre),
      ),
    );
    if (ok && mounted) mostrarExito(context, 'Mecánico añadido');
  }

  Future<void> _renombrar(CargaMecanico c) async {
    final m = c.mecanico;
    final ok = await abrirDialogo(
      context,
      DialogoTexto(
        titulo: 'Renombrar mecánico',
        etiqueta: 'Nombre',
        icono: Icons.badge_outlined,
        inicial: m.nombre,
        guardar: (nombre) =>
            repo.guardarMecanico(id: m.id, nombre: nombre, activo: m.activo),
      ),
    );
    if (ok && mounted) mostrarExito(context, 'Nombre actualizado');
  }

  Future<void> _cambiarActivo(CargaMecanico c, bool activo) async {
    final m = c.mecanico;
    // Aviso amable si se desactiva a alguien con trabajo pendiente.
    if (!activo && c.abiertas > 0) {
      final ok = await confirmar(context,
          titulo: 'Desactivar a ${m.nombre}',
          mensaje: 'Tiene ${c.abiertas} orden(es) abierta(s), que seguirán '
              'asignadas a él. Puede cambiarlas desde cada orden.',
          textoConfirmar: 'Desactivar');
      if (!ok || !mounted) return;
    }
    await ejecutarAccion(
      context,
      () => repo.guardarMecanico(id: m.id, nombre: m.nombre, activo: activo),
      exito: activo ? '${m.nombre} activado' : '${m.nombre} desactivado',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mecánicos')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Añadir'),
        onPressed: _nuevo,
      ),
      body: StreamBuilder<List<CargaMecanico>>(
        stream: _carga,
        builder: (context, snap) {
          if (snap.hasError) return MensajeError(snap.error);
          if (!snap.hasData) return const Cargando();
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const MensajeVacio(
                icono: Icons.engineering_outlined,
                titulo: 'No hay mecánicos registrados');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12, left: 4),
                child: Text('Toque un mecánico para cambiar su nombre.',
                    style: TextStyle(color: Paleta.textoSecundario)),
              ),
              for (final c in lista)
                Tarjeta(
                  onTap: () => _renombrar(c),
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: c.mecanico.activo
                            ? Paleta.primarioSuave
                            : Paleta.borde,
                        child: Text(iniciales(c.mecanico.nombre),
                            style: TextStyle(
                                color: c.mecanico.activo
                                    ? Paleta.primarioOscuro
                                    : Paleta.textoSecundario)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.mecanico.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              c.mecanico.activo
                                  ? '${c.abiertas} abiertas · '
                                      '${c.enReparacion} en reparación · '
                                      '${c.listas} listas'
                                  : 'Inactivo',
                              style: const TextStyle(
                                  color: Paleta.textoSecundario, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Switch: activo / inactivo.
                      Switch(
                        value: c.mecanico.activo,
                        onChanged: (v) => _cambiarActivo(c, v),
                      ),
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
