// =============================================================================
// taller_scope.dart
// InheritedWidget que pone el RepositorioTaller a disposición de toda la app
// (inyección de dependencias sin paquetes externos). Cualquier pantalla obtiene
// el repositorio con:  final repo = TallerScope.of(context);
// =============================================================================
import 'package:flutter/widgets.dart';

import 'repositorio_taller.dart';

class TallerScope extends InheritedWidget {
  final RepositorioTaller repo;

  const TallerScope({super.key, required this.repo, required super.child});

  static RepositorioTaller of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TallerScope>();
    assert(scope != null, 'No hay un TallerScope encima de este widget.');
    return scope!.repo;
  }

  // El repositorio no cambia durante la vida de la app.
  @override
  bool updateShouldNotify(TallerScope oldWidget) => repo != oldWidget.repo;
}
