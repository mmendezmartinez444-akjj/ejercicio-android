// =============================================================================
// modelos.dart
// Clases de "vista" (no son tablas). Combinan datos de varias tablas para que
// las pantallas no tengan que hacer cálculos: total, pagado, saldo, etc.
// =============================================================================
import 'base_datos.dart';

/// Error de regla de negocio: se muestra tal cual al usuario.
class ReglaNegocioException implements Exception {
  final String mensaje;
  const ReglaNegocioException(this.mensaje);
  @override
  String toString() => mensaje;
}

extension EstadoOrdenX on EstadoOrden {
  String get etiqueta => switch (this) {
        EstadoOrden.recibida => 'Recibida',
        EstadoOrden.diagnostico => 'En diagnóstico',
        EstadoOrden.reparacion => 'En reparación',
        EstadoOrden.lista => 'Lista para entregar',
        EstadoOrden.entregada => 'Entregada',
        EstadoOrden.cancelada => 'Cancelada',
      };

  /// Abierta = todavía está en el taller (ni entregada ni cancelada).
  bool get abierta =>
      this != EstadoOrden.entregada && this != EstadoOrden.cancelada;

  /// Solo se pueden añadir trabajos/repuestos a órdenes abiertas.
  bool get editable => abierta;

  /// Estado siguiente en el flujo normal (null si ya terminó).
  EstadoOrden? get siguiente => switch (this) {
        EstadoOrden.recibida => EstadoOrden.diagnostico,
        EstadoOrden.diagnostico => EstadoOrden.reparacion,
        EstadoOrden.reparacion => EstadoOrden.lista,
        EstadoOrden.lista => EstadoOrden.entregada,
        EstadoOrden.entregada => null,
        EstadoOrden.cancelada => null,
      };

  /// Estado anterior (para corregir un avance por error).
  EstadoOrden? get anterior => switch (this) {
        EstadoOrden.diagnostico => EstadoOrden.recibida,
        EstadoOrden.reparacion => EstadoOrden.diagnostico,
        EstadoOrden.lista => EstadoOrden.reparacion,
        _ => null,
      };

  /// Estados que forman el flujo normal (sin "cancelada").
  static const List<EstadoOrden> flujo = [
    EstadoOrden.recibida,
    EstadoOrden.diagnostico,
    EstadoOrden.reparacion,
    EstadoOrden.lista,
    EstadoOrden.entregada,
  ];

  static const List<EstadoOrden> abiertos = [
    EstadoOrden.recibida,
    EstadoOrden.diagnostico,
    EstadoOrden.reparacion,
    EstadoOrden.lista,
  ];
}

/// Una orden con los datos del vehículo, cliente y mecánico, más los totales.
class OrdenResumen {
  final int id;
  final DateTime fechaEntrada;
  final DateTime? fechaEntrega;
  final EstadoOrden estado;
  final String problema;
  final int kilometrajeEntrada;
  final int vehiculoId;
  final String matricula;
  final String marca;
  final String modelo;
  final int anio;
  final int clienteId;
  final String clienteNombre;
  final String clienteTelefono;
  final int mecanicoId;
  final String mecanicoNombre;
  final double manoObra;
  final double totalRepuestos;
  final double pagado;

  const OrdenResumen({
    required this.id,
    required this.fechaEntrada,
    required this.fechaEntrega,
    required this.estado,
    required this.problema,
    required this.kilometrajeEntrada,
    required this.vehiculoId,
    required this.matricula,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.clienteId,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.mecanicoId,
    required this.mecanicoNombre,
    required this.manoObra,
    required this.totalRepuestos,
    required this.pagado,
  });

  double get total => manoObra + totalRepuestos;
  double get saldo => total - pagado;
  bool get pagadaCompleta => total > 0 && saldo <= 0.009;
  String get vehiculoTexto => '$marca $modelo ($anio)';
}

/// Línea de repuesto usado con su nombre y código.
class RepuestoUsadoDetalle {
  final int id;
  final int repuestoId;
  final String codigo;
  final String nombre;
  final int cantidad;
  final double precioUnitario;

  const RepuestoUsadoDetalle({
    required this.id,
    required this.repuestoId,
    required this.codigo,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;
}

/// Cliente con cantidad de vehículos y saldo pendiente.
class ClienteResumen {
  final Cliente cliente;
  final int vehiculos;
  final double saldoPendiente;
  const ClienteResumen(this.cliente, this.vehiculos, this.saldoPendiente);
}

/// Vehículo con el nombre de su dueño (para buscar al crear una orden).
class VehiculoConCliente {
  final Vehiculo vehiculo;
  final String clienteNombre;
  const VehiculoConCliente(this.vehiculo, this.clienteNombre);
}

/// Carga de trabajo de un mecánico.
class CargaMecanico {
  final Mecanico mecanico;
  final int abiertas;
  final int enDiagnostico;
  final int enReparacion;
  final int listas;
  const CargaMecanico({
    required this.mecanico,
    required this.abiertas,
    required this.enDiagnostico,
    required this.enReparacion,
    required this.listas,
  });
}

/// Cliente con deuda (saldo pendiente en órdenes terminadas).
class Deudor {
  final int clienteId;
  final String nombre;
  final String telefono;
  final int ordenesConSaldo;
  final double saldo;
  const Deudor({
    required this.clienteId,
    required this.nombre,
    required this.telefono,
    required this.ordenesConSaldo,
    required this.saldo,
  });
}

/// Resultado del reporte de facturación de un período.
class ReporteFacturacion {
  final DateTime desde;
  final DateTime hasta;
  final List<OrdenResumen> ordenes; // órdenes entregadas en el período
  final double cobrado; // dinero recibido (pagos) en el período

  const ReporteFacturacion({
    required this.desde,
    required this.hasta,
    required this.ordenes,
    required this.cobrado,
  });

  double get manoObra => ordenes.fold(0.0, (s, o) => s + o.manoObra);
  double get repuestos => ordenes.fold(0.0, (s, o) => s + o.totalRepuestos);
  double get facturado => manoObra + repuestos;
  int get cantidad => ordenes.length;
}

/// Resultado de usar un repuesto: si quedó por debajo del mínimo se avisa.
class ResultadoUsoRepuesto {
  final Repuesto repuesto; // con las existencias ya descontadas
  bool get quedoBajo => repuesto.existencias <= repuesto.stockMinimo;
  const ResultadoUsoRepuesto(this.repuesto);
}
