// =============================================================================
// main.dart
// Punto de entrada de la solución C "Pistón Recepción".
//   1. Abre la base de datos local (Drift/SQLite) y crea el repositorio.
//   2. Lo inyecta en todo el árbol de widgets con TallerScope
//      (InheritedWidget) para que cualquier pantalla lo obtenga con
//      TallerScope.of(context).
//   3. Configura MaterialApp: tema claro con Poppins, idioma español
//      (también para el calendario de showDateRangePicker) y la pantalla de
//      inicio tipo "hub".
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/base_datos.dart';
import 'data/repositorio_taller.dart';
import 'data/taller_scope.dart';
import 'ui/pantallas/inicio_pantalla.dart';
import 'ui/tema.dart';

void main() {
  // Necesario antes de usar plugins (path_provider/SQLite) fuera de runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final repo = RepositorioTaller(db);
  runApp(TallerScope(repo: repo, child: const MiApp()));
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pistón Recepción',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      // Localización: textos de Material (botones de diálogos, calendario,
      // DateRangePicker) en español.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const InicioPantalla(),
    );
  }
}
