// =============================================================================
// formato.dart
// Funciones para mostrar dinero, fechas y números sin depender de paquetes
// externos (la app funciona totalmente sin conexión).
// =============================================================================

/// Moneda usada por el taller.
const String kMoneda = 'CUP';

/// 1234.5 -> "1,234.50 CUP"
String dinero(double valor, {bool conMoneda = true}) {
  final negativo = valor < 0;
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final entero = _miles(partes[0]);
  final texto = '${negativo ? '-' : ''}$entero.${partes[1]}';
  return conMoneda ? '$texto $kMoneda' : texto;
}

/// 150000 -> "150,000"
String numero(int valor) => _miles(valor.toString());

String _miles(String digitos) {
  final b = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) b.write(',');
    b.write(digitos[i]);
  }
  return b.toString();
}

String _dos(int n) => n.toString().padLeft(2, '0');

/// 05/11/2026
String fecha(DateTime d) => '${_dos(d.day)}/${_dos(d.month)}/${d.year}';

/// 05/11/2026 14:30
String fechaHora(DateTime d) => '${fecha(d)} ${_dos(d.hour)}:${_dos(d.minute)}';

const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// "5 nov"
String fechaCorta(DateTime d) => '${d.day} ${_meses[d.month - 1]}';

/// "hoy", "ayer", "hace 3 días"
String haceCuanto(DateTime d) {
  final hoy = DateTime.now();
  // En UTC para que un cambio de horario (día de 23 o 25 h) no altere la cuenta.
  final a = DateTime.utc(hoy.year, hoy.month, hoy.day);
  final b = DateTime.utc(d.year, d.month, d.day);
  final dias = a.difference(b).inDays;
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  return 'hace $dias días';
}

/// Convierte texto a double aceptando coma o punto decimal.
double? leerDinero(String texto) =>
    double.tryParse(texto.trim().replaceAll(' ', '').replaceAll(',', '.'));

/// Convierte texto a entero ignorando separadores de miles.
int? leerEntero(String texto) =>
    int.tryParse(texto.trim().replaceAll(RegExp(r'[\s,\.]'), ''));
