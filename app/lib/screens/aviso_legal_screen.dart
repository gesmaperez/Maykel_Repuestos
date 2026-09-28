import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_service.dart';
import '../config.dart';
import '../models.dart';

/// Muestra el aviso legal, leído desde SiteContent.actual (lo que haya
/// cargado la pantalla anterior). Vuelve a pedirlo al backend por si el
/// administrador lo acaba de editar, para no mostrar una versión vieja.
class AvisoLegalScreen extends StatefulWidget {
  const AvisoLegalScreen({super.key});

  @override
  State<AvisoLegalScreen> createState() => _AvisoLegalScreenState();
}

class _AvisoLegalScreenState extends State<AvisoLegalScreen> {
  @override
  void initState() {
    super.initState();
    _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      final contenido = await ApiService.instance.getContenido();
      if (!mounted) return;
      setState(() => SiteContent.actual = contenido);
    } catch (_) {
      // Si falla, se muestra lo que ya había en SiteContent.actual.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteContent.actual;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.char,
        title: const Text('Aviso legal — Maykel Repuestos'),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aviso legal y términos de uso',
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.char),
                ),
                const SizedBox(height: 6),
                Text('Última actualización: ${c.avisoLegalActualizado}',
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12, color: AppColors.steel)),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    border: const Border(left: BorderSide(color: AppColors.yellow, width: 3)),
                  ),
                  child: Text(
                    'Este texto es una referencia general y no reemplaza asesoría legal '
                    'profesional. Se recomienda revisarlo con un abogado antes de publicar '
                    'el sitio, especialmente en lo relativo a protección de datos personales.',
                    style: TextStyle(fontSize: 13, color: AppColors.steel, height: 1.6),
                  ),
                ),
                for (final seccion in c.avisoLegalSecciones)
                  seccion.items.isEmpty
                      ? _seccion(seccion.titulo, seccion.texto)
                      : _seccionConLista(seccion.titulo, seccion.texto, seccion.items),
                const SizedBox(height: 24),
                Wrap(
                  children: [
                    const Text(
                      'Para contactarnos directamente, puedes escribir a ',
                      style: TextStyle(fontSize: 14.5, height: 1.75, color: Color(0xFF333333)),
                    ),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('mailto:${c.contactoEmail}')),
                      child: Text(c.contactoEmail,
                          style: const TextStyle(
                              fontSize: 14.5, color: AppColors.red, decoration: TextDecoration.underline)),
                    ),
                    const Text(' o por WhatsApp al ',
                        style: TextStyle(fontSize: 14.5, height: 1.75, color: Color(0xFF333333))),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse('https://wa.me/${c.contactoWhatsapp}')),
                      child: Text('+${c.contactoWhatsapp}',
                          style: const TextStyle(
                              fontSize: 14.5, color: AppColors.red, decoration: TextDecoration.underline)),
                    ),
                    const Text('.',
                        style: TextStyle(fontSize: 14.5, height: 1.75, color: Color(0xFF333333))),
                  ],
                ),
                const SizedBox(height: 40),
                Text('© ${DateTime.now().year} Maykel Repuestos. Todos los derechos reservados.',
                    style: TextStyle(fontSize: 12, color: AppColors.steel)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seccion(String titulo, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 19)),
          const SizedBox(height: 10),
          Text(texto,
              style: const TextStyle(fontSize: 14.5, height: 1.75, color: Color(0xFF333333))),
        ],
      ),
    );
  }

  Widget _seccionConLista(String titulo, String intro, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 19)),
          const SizedBox(height: 10),
          Text(intro,
              style: const TextStyle(fontSize: 14.5, height: 1.75, color: Color(0xFF333333))),
          const SizedBox(height: 6),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 14.5)),
                    Expanded(
                      child: Text(it,
                          style: const TextStyle(
                              fontSize: 14.5, height: 1.75, color: Color(0xFF333333))),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
