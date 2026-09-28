import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_service.dart';
import '../config.dart';
import '../models.dart';
import '../widgets/admin_login_dialog.dart';
import '../widgets/product_card.dart';
import '../widgets/reserva_dialog.dart';
import 'admin_screen.dart';
import 'aviso_legal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _historiaKey = GlobalKey();
  final _serviciosKey = GlobalKey();
  final _catalogoKey = GlobalKey();
  final _contactoKey = GlobalKey();
  final _scrollController = ScrollController();

  List<Repuesto> _productos = [];
  bool _cargando = true;
  String? _error;

  String _busqueda = '';
  String _categoriaActiva = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _cargarContenido();
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final productos = await ApiService.instance.getRepuestos();
      setState(() {
        _productos = productos;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _cargarContenido() async {
    try {
      final contenido = await ApiService.instance.getContenido();
      if (!mounted) return;
      setState(() => SiteContent.actual = contenido);
    } catch (_) {
      // Si falla, el sitio sigue mostrando el contenido de referencia
      // (SiteContent.actual ya trae ContenidoSitio.porDefecto() por defecto).
    }
  }

  List<String> get _categorias {
    final set = <String>{};
    for (final p in _productos) {
      if (p.categoria.isNotEmpty) set.add(p.categoria);
    }
    final lista = set.toList()..sort();
    return ['Todos', ...lista];
  }

  List<Repuesto> get _filtrados {
    final termino = _busqueda.trim().toLowerCase();
    return _productos.where((p) {
      final matchCat = _categoriaActiva == 'Todos' || p.categoria == _categoriaActiva;
      final matchTermino = termino.isEmpty ||
          p.nombre.toLowerCase().contains(termino) ||
          p.marca.toLowerCase().contains(termino) ||
          p.sku.toLowerCase().contains(termino);
      return matchCat && matchTermino;
    }).toList();
  }

  void _scrollA(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  Future<void> _abrirAdmin() async {
    final ok = await mostrarLoginAdmin(context);
    if (ok == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminScreen()),
      );
      _cargarProductos();
    }
  }

  void _abrirReserva(Repuesto p) {
    mostrarDialogoReserva(context, p, _cargarProductos);
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esAngosto = ancho < 760;

    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildNavbar(esAngosto),
            _buildHero(esAngosto),
            Container(key: _historiaKey, child: _buildHistoria(esAngosto)),
            Container(key: _serviciosKey, child: _buildServicios(esAngosto)),
            Container(key: _catalogoKey, child: _buildCatalogo(esAngosto)),
            Container(key: _contactoKey, child: _buildContacto(esAngosto)),
            _buildFooter(esAngosto),
          ],
        ),
      ),
    );
  }

  // ---------- Navbar ----------

  Widget _buildNavbar(bool esAngosto) {
    return Container(
      color: AppColors.char,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/logo.jpg', width: 34, height: 34, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Text(
            SiteContent.actual.nombreNegocio,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (!esAngosto) ...[
            _navLink('Historia', () => _scrollA(_historiaKey)),
            _navLink('Servicios', () => _scrollA(_serviciosKey)),
            _navLink('Catálogo', () => _scrollA(_catalogoKey)),
            _navLink('Contacto', () => _scrollA(_contactoKey)),
            const SizedBox(width: 12),
          ],
          TextButton.icon(
            onPressed: _abrirAdmin,
            icon: const Icon(Icons.lock_outline, size: 16, color: Colors.white70),
            label: const Text('Admin', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _navLink(String texto, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        child: Text(texto,
            style: const TextStyle(color: Colors.white, fontSize: 13.5)),
      ),
    );
  }

  // ---------- Hero ----------

  Widget _buildHero(bool esAngosto) {
    return Container(
      width: double.infinity,
      color: AppColors.char2,
      padding: EdgeInsets.symmetric(
          horizontal: esAngosto ? 20 : 60, vertical: esAngosto ? 40 : 70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SiteContent.actual.heroTitulo,
            style: TextStyle(
              color: Colors.white,
              fontSize: esAngosto ? 32 : 48,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              SiteContent.actual.heroSubtitulo,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: () => _scrollA(_catalogoKey),
                child: Text(SiteContent.actual.heroBotonCatalogo),
              ),
              OutlinedButton(
                onPressed: () => _scrollA(_contactoKey),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                child: Text(SiteContent.actual.heroBotonContacto),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              _statHero('${_productos.length}', SiteContent.actual.heroEstadisticaProductosEtiqueta),
              _statHero(SiteContent.actual.heroEstadisticaMarcasValor,
                  SiteContent.actual.heroEstadisticaMarcasEtiqueta),
              _statHero(SiteContent.actual.heroEstadisticaCategoriasValor,
                  SiteContent.actual.heroEstadisticaCategoriasEtiqueta),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statHero(String numero, String etiqueta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(numero,
            style: const TextStyle(
                color: AppColors.yellow, fontSize: 26, fontWeight: FontWeight.w900)),
        Text(etiqueta, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  // ---------- Historia ----------

  Widget _buildHistoria(bool esAngosto) {
    return Container(
      width: double.infinity,
      color: AppColors.paper,
      padding: EdgeInsets.symmetric(
          horizontal: esAngosto ? 20 : 60, vertical: esAngosto ? 40 : 60),
      child: Flex(
        direction: esAngosto ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SiteContent.actual.historiaKicker,
                    style: TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1)),
                const SizedBox(height: 10),
                Text(
                  SiteContent.actual.historiaTitulo,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.char),
                ),
                const SizedBox(height: 14),
                Text(
                  SiteContent.actual.historiaTexto,
                  style: TextStyle(color: AppColors.steel, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
          if (!esAngosto) const SizedBox(width: 40),
          if (esAngosto) const SizedBox(height: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: SiteContent.actual.historiaFichas
                  .map((f) => _filaFicha(f.etiqueta, f.valor))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaFicha(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 4, height: 34, color: AppColors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.steel, fontWeight: FontWeight.w700)),
                Text(valor,
                    style: const TextStyle(fontSize: 14, color: AppColors.char)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Servicios ----------

  Widget _buildServicios(bool esAngosto) {
    final servicios = SiteContent.actual.servicios;

    return Container(
      width: double.infinity,
      color: AppColors.char,
      padding: EdgeInsets.symmetric(
          horizontal: esAngosto ? 20 : 60, vertical: esAngosto ? 40 : 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SiteContent.actual.serviciosKicker,
              style: TextStyle(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(
            SiteContent.actual.serviciosTitulo,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: servicios
                .map((s) => Container(
                      width: esAngosto ? double.infinity : 260,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.char2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.red, size: 22),
                          const SizedBox(height: 12),
                          Text(s.titulo,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          const SizedBox(height: 6),
                          Text(s.descripcion,
                              style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.5)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---------- Catálogo ----------

  Widget _buildCatalogo(bool esAngosto) {
    return Container(
      width: double.infinity,
      color: AppColors.paper,
      padding: EdgeInsets.symmetric(
          horizontal: esAngosto ? 20 : 60, vertical: esAngosto ? 40 : 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SiteContent.actual.catalogoKicker,
              style: TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(SiteContent.actual.catalogoTitulo,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.char)),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: SiteContent.actual.catalogoBusquedaHint,
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
          const SizedBox(height: 14),
          if (!_cargando)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categorias.map((c) {
                final activo = c == _categoriaActiva;
                return ChoiceChip(
                  label: Text(c),
                  selected: activo,
                  selectedColor: AppColors.red,
                  labelStyle: TextStyle(
                    color: activo ? Colors.white : AppColors.char,
                    fontSize: 12.5,
                  ),
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() => _categoriaActiva = c),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
          if (_cargando)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text('No se pudo cargar el catálogo: $_error',
                  style: TextStyle(color: AppColors.bad)),
            )
          else if (_filtrados.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text('No encontramos repuestos que coincidan con tu búsqueda.',
                  style: TextStyle(color: AppColors.steel)),
            )
          else if (esAngosto)
            Column(
              children: _filtrados
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ProductCard(
                          producto: p,
                          onReservar: () => _abrirReserva(p),
                        ),
                      ))
                  .toList(),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _filtrados
                  .map((p) => SizedBox(
                        width: 260,
                        child: ProductCard(
                          producto: p,
                          onReservar: () => _abrirReserva(p),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  // ---------- Contacto ----------

  Widget _buildContacto(bool esAngosto) {
    final tarjetas = <(String, String, VoidCallback?)>[
      ('WhatsApp', '+${SiteContent.actual.contactoWhatsapp}',
          () => launchUrl(Uri.parse('https://wa.me/${SiteContent.actual.contactoWhatsapp}'))),
      ('Correo', SiteContent.actual.contactoEmail,
          () => launchUrl(Uri.parse('mailto:${SiteContent.actual.contactoEmail}'))),
      ('Dirección', SiteContent.actual.contactoDireccion,
          () => launchUrl(Uri.parse(SiteContent.actual.contactoMapsUrl))),
      ('Horario', SiteContent.actual.contactoHorario, null),
    ];

    return Container(
      width: double.infinity,
      color: AppColors.char2,
      padding: EdgeInsets.symmetric(
          horizontal: esAngosto ? 20 : 60, vertical: esAngosto ? 40 : 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(SiteContent.actual.contactoKicker,
              style: TextStyle(
                  color: AppColors.yellow,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(SiteContent.actual.contactoTitulo,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          esAngosto
              ? Column(
                  children: tarjetas
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _tarjetaContacto(t, esAngosto),
                          ))
                      .toList(),
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: tarjetas.map((t) => _tarjetaContacto(t, esAngosto)).toList(),
                ),
        ],
      ),
    );
  }

  Widget _tarjetaContacto((String, String, VoidCallback?) t, bool esAngosto) {
    return Container(
      width: esAngosto ? double.infinity : 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.char,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: InkWell(
        onTap: t.$3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.$1,
                style: const TextStyle(
                    color: AppColors.yellow, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 8),
            Text(t.$2, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }

  // ---------- Footer ----------

  Widget _buildFooter(bool esAngosto) {
    return Container(
      width: double.infinity,
      color: AppColors.char,
      padding: EdgeInsets.symmetric(horizontal: esAngosto ? 20 : 60, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/logo.jpg', width: 26, height: 26, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              Text(SiteContent.actual.nombreNegocio,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              InkWell(
                onTap: () =>
                    launchUrl(Uri.parse('https://wa.me/${SiteContent.actual.contactoWhatsapp}')),
                child: Text('WhatsApp: +${SiteContent.actual.contactoWhatsapp}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
              ),
              InkWell(
                onTap: () => launchUrl(Uri.parse('mailto:${SiteContent.actual.contactoEmail}')),
                child: Text(SiteContent.actual.contactoEmail,
                    style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
              ),
              InkWell(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AvisoLegalScreen())),
                child: const Text('Aviso legal',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5)),
              ),
              InkWell(
                onTap: _abrirAdmin,
                child: const Text('Acceso administrador',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('© ${DateTime.now().year} ${SiteContent.actual.footerDerechos}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}
