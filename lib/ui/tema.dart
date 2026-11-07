// =============================================================================
// tema.dart
// Identidad visual de la solución C "Pistón Recepción": tema CLARO, suave y
// moderno pensado para la recepcionista y el dueño.
//   - Colores de la marca (clase Paleta).
//   - ThemeData de Material 3 con la fuente Poppins (construirTema).
//   - Ayudas visuales para los estados de una orden (extensión EstadoOrdenUI):
//     colores "píldora" pastel, icono y texto del botón de la siguiente acción.
//   - Decoración común de los campos de texto (decoracionCampo).
//   - Saludo según la hora del día (saludoSegunHora).
// =============================================================================
import 'package:flutter/material.dart';

import '../data/tablas.dart';

/// Colores de la solución. Se usan como constantes en toda la interfaz para
/// que el diseño sea coherente (un solo lugar donde cambiarlos).
class Paleta {
  Paleta._(); // No se instancia: solo contiene constantes.

  static const Color fondo = Color(0xFFF6F8F7);
  static const Color tarjeta = Color(0xFFFFFFFF);
  static const Color primario = Color(0xFF0D9488); // verde azulado
  static const Color primarioOscuro = Color(0xFF115E59);
  static const Color primarioSuave = Color(0xFFCCFBF1); // fondo de iconos
  static const Color acento = Color(0xFFF97361); // coral
  static const Color acentoSuave = Color(0xFFFFE4DE);
  static const Color aviso = Color(0xFFF59E0B); // ámbar
  static const Color avisoSuave = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color texto = Color(0xFF1F2937);
  static const Color textoSecundario = Color(0xFF6B7280);
  static const Color borde = Color(0xFFE5E7EB);
  static const Color exito = Color(0xFF166534);
}

/// Radio de los bordes: "muy redondeados" según el diseño.
const double kRadio = 20;

/// Radio usado en los campos de texto y botones (un poco menor).
const double kRadioCampo = 16;

/// Construye el ThemeData de la aplicación.
/// Nota: no se configuran cardTheme/dialogTheme/tabBarTheme porque su tipo
/// cambió entre versiones de Flutter; las tarjetas se estilizan con el widget
/// propio `Tarjeta` (widgets/tarjeta.dart).
ThemeData construirTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Paleta.primario,
    primary: Paleta.primario,
    onPrimary: Colors.white,
    secondary: Paleta.acento,
    onSecondary: Colors.white,
    error: Paleta.error,
    surface: Paleta.fondo, // AppBar y fondos usan este color en Material 3
    onSurface: Paleta.texto,
  );

  final botonForma = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kRadioCampo),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins', // fuente incluida en assets/fonts (pubspec.yaml)
    colorScheme: esquema,
    scaffoldBackgroundColor: Paleta.fondo,
    // Textos: pesos 400/500/600/700 de Poppins.
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: Paleta.texto),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, color: Paleta.texto),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Paleta.texto),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, color: Paleta.texto),
      bodyLarge: TextStyle(color: Paleta.texto),
      bodyMedium: TextStyle(color: Paleta.texto),
      bodySmall: TextStyle(color: Paleta.textoSecundario),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: botonForma,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
            fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: botonForma,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: const BorderSide(color: Paleta.borde),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: botonForma),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Paleta.primario,
      foregroundColor: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadio)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadioCampo)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Paleta.primarioOscuro),
    dividerTheme: const DividerThemeData(color: Paleta.borde, thickness: 1),
  );
}

/// Decoración común de los campos de formulario: rellenos de blanco, con
/// bordes redondeados y un icono opcional. Se usa en vez de
/// inputDecorationTheme para no depender de la versión de Flutter.
InputDecoration decoracionCampo(
  String etiqueta, {
  IconData? icono,
  String? ayuda,
  String? sufijo,
  String? pista,
}) {
  OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadioCampo),
        borderSide: BorderSide(color: color, width: ancho),
      );
  return InputDecoration(
    labelText: etiqueta,
    hintText: pista,
    helperText: ayuda,
    suffixText: sufijo,
    prefixIcon: icono == null ? null : Icon(icono),
    filled: true,
    fillColor: Paleta.tarjeta,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: borde(Paleta.borde),
    enabledBorder: borde(Paleta.borde),
    focusedBorder: borde(Paleta.primario, 2),
    errorBorder: borde(Paleta.error),
    focusedErrorBorder: borde(Paleta.error, 2),
  );
}

/// Ayudas visuales para cada estado de una orden. Es una extensión: añade
/// getters al enum EstadoOrden sin modificar el núcleo de datos.
extension EstadoOrdenUI on EstadoOrden {
  /// Fondo pastel de la "píldora".
  Color get colorFondo => switch (this) {
        EstadoOrden.recibida => const Color(0xFFE0E7FF),
        EstadoOrden.diagnostico => const Color(0xFFE0F2FE),
        EstadoOrden.reparacion => const Color(0xFFFEF3C7),
        EstadoOrden.lista => const Color(0xFFDCFCE7),
        EstadoOrden.entregada => const Color(0xFFF3F4F6),
        EstadoOrden.cancelada => const Color(0xFFFEE2E2),
      };

  /// Texto oscuro de la "píldora" (buen contraste sobre el pastel).
  Color get colorTexto => switch (this) {
        EstadoOrden.recibida => const Color(0xFF3730A3),
        EstadoOrden.diagnostico => const Color(0xFF075985),
        EstadoOrden.reparacion => const Color(0xFF92400E),
        EstadoOrden.lista => const Color(0xFF166534),
        EstadoOrden.entregada => const Color(0xFF374151),
        EstadoOrden.cancelada => const Color(0xFF991B1B),
      };

  IconData get icono => switch (this) {
        EstadoOrden.recibida => Icons.inbox_outlined,
        EstadoOrden.diagnostico => Icons.search,
        EstadoOrden.reparacion => Icons.build_outlined,
        EstadoOrden.lista => Icons.check_circle_outline,
        EstadoOrden.entregada => Icons.directions_car_filled_outlined,
        EstadoOrden.cancelada => Icons.block,
      };

  /// Texto del botón principal del detalle (acción para pasar al siguiente
  /// estado). Es null si la orden ya terminó.
  String? get textoSiguienteAccion => switch (this) {
        EstadoOrden.recibida => 'Pasar a diagnóstico',
        EstadoOrden.diagnostico => 'Pasar a reparación',
        EstadoOrden.reparacion => 'Marcar lista para entregar',
        EstadoOrden.lista => 'Entregar al cliente',
        EstadoOrden.entregada => null,
        EstadoOrden.cancelada => null,
      };
}

/// "Buenos días" / "Buenas tardes" / "Buenas noches" según la hora.
String saludoSegunHora(DateTime ahora) {
  if (ahora.hour < 12) return 'Buenos días';
  if (ahora.hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Iniciales de un nombre para el CircleAvatar ("María González" -> "MG").
String iniciales(String nombre) {
  final partes =
      nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes[0][0] + partes[1][0]).toUpperCase();
}
