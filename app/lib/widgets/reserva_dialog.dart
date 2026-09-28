import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_service.dart';
import '../config.dart';
import '../models.dart';

/// Abre el diálogo de reserva para un producto. Al confirmar, muestra el
/// ticket de la reserva con botones para enviarla por WhatsApp o correo.
Future<void> mostrarDialogoReserva(
  BuildContext context,
  Repuesto producto,
  VoidCallback onReservaCreada,
) {
  return showDialog(
    context: context,
    builder: (_) => _ReservaDialog(
      producto: producto,
      onReservaCreada: onReservaCreada,
    ),
  );
}

class _ReservaDialog extends StatefulWidget {
  final Repuesto producto;
  final VoidCallback onReservaCreada;

  const _ReservaDialog({required this.producto, required this.onReservaCreada});

  @override
  State<_ReservaDialog> createState() => _ReservaDialogState();
}

class _ReservaDialogState extends State<_ReservaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  late final TextEditingController _cantidadCtrl;

  bool _enviando = false;
  String? _error;
  Reserva? _reservaCreada;

  @override
  void initState() {
    super.initState();
    _cantidadCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _notaCtrl.dispose();
    _cantidadCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    final cantidad = int.tryParse(_cantidadCtrl.text) ?? 0;
    final stockDisponible = widget.producto.stock;
    if (cantidad < 1 || cantidad > stockDisponible) {
      setState(() => _error = 'Cantidad no disponible en stock.');
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
    });

    try {
      final reserva = await ApiService.instance.crearReserva(
        repuestoId: widget.producto.id,
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        cantidad: cantidad,
        nota: _notaCtrl.text.trim(),
      );
      widget.onReservaCreada();
      setState(() => _reservaCreada = reserva);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: _reservaCreada != null
                ? _buildTicket(_reservaCreada!)
                : _buildFormulario(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    final p = widget.producto;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reservar producto',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${p.sku} · ${p.stock} disponibles',
                    style: TextStyle(color: AppColors.steel, fontSize: 12)),
              ],
            ),
          ),
          TextFormField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telefonoCtrl,
            decoration: const InputDecoration(
                labelText: 'Teléfono (WhatsApp)', hintText: '+56 9 1234 5678'),
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cantidadCtrl,
            decoration: const InputDecoration(labelText: 'Cantidad'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1) return 'Cantidad inválida';
              if (n > p.stock) return 'Cantidad no disponible en stock';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notaCtrl,
            decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Ej: modelo y año del vehículo'),
            maxLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppColors.bad, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _enviando ? null : _confirmar,
            child: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirmar reserva'),
          ),
          const SizedBox(height: 10),
          Text(
            'Al reservar aceptas nuestro aviso legal.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.steel),
          ),
        ],
      ),
    );
  }

  Widget _buildTicket(Reserva r) {
    final fecha = DateTime.tryParse(r.fecha) ?? DateTime.now();
    final fechaStr =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    final waTexto = Uri.encodeComponent(
      'Hola, quiero confirmar mi reserva en Maykel Repuestos:\n'
      'Producto: ${r.producto} (${r.sku})\n'
      'Cantidad: ${r.cantidad}\n'
      'Nombre: ${r.nombre}\n'
      'N° de reserva: ${r.id}',
    );
    final mailSubject = Uri.encodeComponent('Reserva ${r.id} — Maykel Repuestos');
    final mailBody = Uri.encodeComponent(
      'Reserva N°: ${r.id}\n'
      'Producto: ${r.producto} (${r.sku})\n'
      'Cantidad: ${r.cantidad}\n\n'
      'Nombre: ${r.nombre}\nTeléfono: ${r.telefono}\nCorreo: ${r.email}\n'
      '${r.nota.isNotEmpty ? 'Comentario: ${r.nota}\n' : ''}',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ORDEN DE RESERVA',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.paper2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              _ticketRow('N° reserva', r.id),
              _ticketRow('Fecha', fechaStr),
              _ticketRow('Producto', r.sku),
              _ticketRow('Cantidad', '${r.cantidad}'),
              _ticketRow('Cliente', r.nombre),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Tu reserva quedó registrada. Para confirmarla, envíanosla por '
          'WhatsApp o correo — nuestro equipo te confirmará el retiro o despacho.',
          style: TextStyle(fontSize: 12.5, color: AppColors.steel, height: 1.5),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(
                'https://wa.me/${SiteContent.actual.contactoWhatsapp}?text=$waTexto'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.chat),
          label: const Text('Enviar por WhatsApp'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(
              'mailto:${SiteContent.actual.contactoEmail}?subject=$mailSubject&body=$mailBody')),
          icon: const Icon(Icons.email_outlined),
          label: const Text('Enviar por correo'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.steel, fontSize: 12.5)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}
