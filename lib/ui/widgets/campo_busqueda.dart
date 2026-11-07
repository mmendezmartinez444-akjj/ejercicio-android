// =============================================================================
// campo_busqueda.dart
// Campo de búsqueda redondeado (tipo "píldora") con botón para limpiar.
// Es StatefulWidget porque es dueño de su TextEditingController (lo crea en
// initState y lo libera en dispose) y necesita redibujar el botón "x".
// Avisa a la pantalla con el callback [onCambio] cada vez que cambia el texto.
// =============================================================================
import 'package:flutter/material.dart';

import '../tema.dart';

class CampoBusqueda extends StatefulWidget {
  final String pista;
  final ValueChanged<String> onCambio;

  const CampoBusqueda({super.key, required this.pista, required this.onCambio});

  @override
  State<CampoBusqueda> createState() => _CampoBusquedaState();
}

class _CampoBusquedaState extends State<CampoBusqueda> {
  final _controlador = TextEditingController();

  @override
  void dispose() {
    _controlador.dispose(); // evita fugas de memoria
    super.dispose();
  }

  void _limpiar() {
    _controlador.clear();
    widget.onCambio('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const bordeRedondo = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(30)),
      borderSide: BorderSide(color: Paleta.borde),
    );
    return TextField(
      controller: _controlador,
      textInputAction: TextInputAction.search,
      onChanged: (texto) {
        widget.onCambio(texto);
        setState(() {}); // muestra u oculta el botón de limpiar
      },
      decoration: InputDecoration(
        hintText: widget.pista,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controlador.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar',
                icon: const Icon(Icons.close),
                onPressed: _limpiar,
              ),
        filled: true,
        fillColor: Paleta.tarjeta,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: bordeRedondo,
        enabledBorder: bordeRedondo,
        focusedBorder: bordeRedondo.copyWith(
            borderSide: const BorderSide(color: Paleta.primario, width: 2)),
      ),
    );
  }
}
