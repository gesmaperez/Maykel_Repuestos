import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../config.dart';
import '../models.dart';
import '../utils/format.dart';
import '../utils/pdf_report.dart';

/// Panel de administración con navegación lateral (sidebar), igual que el
/// diseño de referencia: Inicio, Analítica, Catálogo, Reservas, Stock,
/// Usuarios (roles y accesos) y Configuración.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _Seccion {
  final String clave;
  final String etiqueta;
  final IconData icono;
  final String? permiso; // null = siempre visible
  const _Seccion(this.clave, this.etiqueta, this.icono, this.permiso);
}

const _secciones = [
  _Seccion('inicio', 'Inicio', Icons.home_outlined, null),
  _Seccion('analitica', 'Analítica', Icons.insights_outlined, 'dashboard'),
  _Seccion('catalogo', 'Catálogo', Icons.grid_view_outlined, 'catalogo'),
  _Seccion('reservas', 'Reservas', Icons.event_note_outlined, 'reservas'),
  _Seccion('stock', 'Stock', Icons.inventory_2_outlined, 'stock'),
  _Seccion('usuarios', 'Usuarios', Icons.people_outline, 'usuarios'),
  _Seccion('configuracion', 'Configuración', Icons.settings_outlined, 'configuracion'),
];

class _AdminScreenState extends State<AdminScreen> {
  String _seccionActiva = 'inicio';

  bool _cargando = true;
  String? _error;

  List<Repuesto> _stock = [];
  List<Reserva> _reservas = [];
  List<Venta> _ventas = [];
  DashboardData? _dashboard;
  List<Rol> _roles = [];
  List<UsuarioAdmin> _usuariosAdmin = [];

  final Map<int, TextEditingController> _precioCtrls = {};
  final Map<int, TextEditingController> _stockCtrls = {};

  int? _ventaProductoId;
  final _ventaCantidadCtrl = TextEditingController(text: '1');
  final _ventaClienteCtrl = TextEditingController();
  final _ventaMetodoPagoCtrl = TextEditingController();
  bool _registrandoVenta = false;
  String? _resultadoVenta;
  bool _resultadoVentaEsError = false;
  bool _guardandoStock = false;

  String _busquedaCatalogo = '';

  // Contenido editable del sitio (Configuración): copia local que se edita
  // y solo se manda al backend cuando el usuario presiona "Guardar".
  ContenidoSitio _contenidoEdit = ContenidoSitio.porDefecto();
  final _nombreNegocioCtrl = TextEditingController();
  final _heroTituloCtrl = TextEditingController();
  final _heroSubtituloCtrl = TextEditingController();
  final _heroBotonCatalogoCtrl = TextEditingController();
  final _heroBotonContactoCtrl = TextEditingController();
  final _heroEstadisticaProductosEtiquetaCtrl = TextEditingController();
  final _heroEstadisticaMarcasValorCtrl = TextEditingController();
  final _heroEstadisticaMarcasEtiquetaCtrl = TextEditingController();
  final _heroEstadisticaCategoriasValorCtrl = TextEditingController();
  final _heroEstadisticaCategoriasEtiquetaCtrl = TextEditingController();
  final _historiaKickerCtrl = TextEditingController();
  final _serviciosKickerCtrl = TextEditingController();
  final _serviciosTituloCtrl = TextEditingController();
  final _catalogoKickerCtrl = TextEditingController();
  final _catalogoTituloCtrl = TextEditingController();
  final _catalogoBusquedaHintCtrl = TextEditingController();
  final _contactoKickerCtrl = TextEditingController();
  final _contactoTituloCtrl = TextEditingController();
  final _footerDerechosCtrl = TextEditingController();
  final _historiaTituloCtrl = TextEditingController();
  final _historiaTextoCtrl = TextEditingController();
  final _contactoWhatsappCtrl = TextEditingController();
  final _contactoEmailCtrl = TextEditingController();
  final _contactoDireccionCtrl = TextEditingController();
  final _contactoMapsUrlCtrl = TextEditingController();
  final _contactoHorarioCtrl = TextEditingController();
  final _avisoLegalActualizadoCtrl = TextEditingController();
  bool _guardandoContenido = false;
  String? _resultadoContenido;
  bool _resultadoContenidoEsError = false;

  SesionAdmin get _sesion =>
      ApiService.instance.sesion ??
      SesionAdmin(usuario: '', permisos: const [], esSuperAdmin: false);

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _ventaCantidadCtrl.dispose();
    _ventaClienteCtrl.dispose();
    _ventaMetodoPagoCtrl.dispose();
    for (final c in _precioCtrls.values) {
      c.dispose();
    }
    for (final c in _stockCtrls.values) {
      c.dispose();
    }
    _nombreNegocioCtrl.dispose();
    _heroTituloCtrl.dispose();
    _heroSubtituloCtrl.dispose();
    _heroBotonCatalogoCtrl.dispose();
    _heroBotonContactoCtrl.dispose();
    _heroEstadisticaProductosEtiquetaCtrl.dispose();
    _heroEstadisticaMarcasValorCtrl.dispose();
    _heroEstadisticaMarcasEtiquetaCtrl.dispose();
    _heroEstadisticaCategoriasValorCtrl.dispose();
    _heroEstadisticaCategoriasEtiquetaCtrl.dispose();
    _historiaKickerCtrl.dispose();
    _serviciosKickerCtrl.dispose();
    _serviciosTituloCtrl.dispose();
    _catalogoKickerCtrl.dispose();
    _catalogoTituloCtrl.dispose();
    _catalogoBusquedaHintCtrl.dispose();
    _contactoKickerCtrl.dispose();
    _contactoTituloCtrl.dispose();
    _footerDerechosCtrl.dispose();
    _historiaTituloCtrl.dispose();
    _historiaTextoCtrl.dispose();
    _contactoWhatsappCtrl.dispose();
    _contactoEmailCtrl.dispose();
    _contactoDireccionCtrl.dispose();
    _contactoMapsUrlCtrl.dispose();
    _contactoHorarioCtrl.dispose();
    _avisoLegalActualizadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        ApiService.instance.getRepuestos(),
        ApiService.instance.getReservasAdmin(),
        ApiService.instance.getVentasAdmin(),
        ApiService.instance.getDashboard(),
        if (_sesion.puede('usuarios')) ApiService.instance.getRoles() else Future.value(<Rol>[]),
        if (_sesion.puede('usuarios'))
          ApiService.instance.getUsuariosAdmin()
        else
          Future.value(<UsuarioAdmin>[]),
        ApiService.instance.getContenido(),
      ]);

      final stock = resultados[0] as List<Repuesto>;
      _sincronizarControladoresStock(stock);
      final contenido = resultados[6] as ContenidoSitio;

      setState(() {
        _stock = stock;
        _reservas = resultados[1] as List<Reserva>;
        _ventas = resultados[2] as List<Venta>;
        _dashboard = resultados[3] as DashboardData;
        _roles = resultados[4] as List<Rol>;
        _usuariosAdmin = resultados[5] as List<UsuarioAdmin>;
        SiteContent.actual = contenido;
        _contenidoEdit = contenido.copiaProfunda();
        _sincronizarControladoresContenido();
        _cargando = false;
        if (_ventaProductoId == null && _stock.isNotEmpty) {
          final disponible =
              _stock.firstWhere((p) => p.stock > 0, orElse: () => _stock.first);
          _ventaProductoId = disponible.id;
        }
        // Si la sección activa no está permitida para este usuario, cae a Inicio.
        final seccion = _secciones.firstWhere((s) => s.clave == _seccionActiva);
        if (seccion.permiso != null && !_sesion.puede(seccion.permiso!)) {
          _seccionActiva = 'inicio';
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  void _sincronizarControladoresStock(List<Repuesto> productos) {
    for (final p in productos) {
      _precioCtrls.putIfAbsent(
          p.id, () => TextEditingController(text: p.precio.round().toString()));
      _stockCtrls.putIfAbsent(
          p.id, () => TextEditingController(text: p.stock.round().toString()));
    }
  }

  void _sincronizarControladoresContenido() {
    _nombreNegocioCtrl.text = _contenidoEdit.nombreNegocio;
    _heroTituloCtrl.text = _contenidoEdit.heroTitulo;
    _heroSubtituloCtrl.text = _contenidoEdit.heroSubtitulo;
    _heroBotonCatalogoCtrl.text = _contenidoEdit.heroBotonCatalogo;
    _heroBotonContactoCtrl.text = _contenidoEdit.heroBotonContacto;
    _heroEstadisticaProductosEtiquetaCtrl.text = _contenidoEdit.heroEstadisticaProductosEtiqueta;
    _heroEstadisticaMarcasValorCtrl.text = _contenidoEdit.heroEstadisticaMarcasValor;
    _heroEstadisticaMarcasEtiquetaCtrl.text = _contenidoEdit.heroEstadisticaMarcasEtiqueta;
    _heroEstadisticaCategoriasValorCtrl.text = _contenidoEdit.heroEstadisticaCategoriasValor;
    _heroEstadisticaCategoriasEtiquetaCtrl.text = _contenidoEdit.heroEstadisticaCategoriasEtiqueta;
    _historiaKickerCtrl.text = _contenidoEdit.historiaKicker;
    _serviciosKickerCtrl.text = _contenidoEdit.serviciosKicker;
    _serviciosTituloCtrl.text = _contenidoEdit.serviciosTitulo;
    _catalogoKickerCtrl.text = _contenidoEdit.catalogoKicker;
    _catalogoTituloCtrl.text = _contenidoEdit.catalogoTitulo;
    _catalogoBusquedaHintCtrl.text = _contenidoEdit.catalogoBusquedaHint;
    _contactoKickerCtrl.text = _contenidoEdit.contactoKicker;
    _contactoTituloCtrl.text = _contenidoEdit.contactoTitulo;
    _footerDerechosCtrl.text = _contenidoEdit.footerDerechos;
    _historiaTituloCtrl.text = _contenidoEdit.historiaTitulo;
    _historiaTextoCtrl.text = _contenidoEdit.historiaTexto;
    _contactoWhatsappCtrl.text = _contenidoEdit.contactoWhatsapp;
    _contactoEmailCtrl.text = _contenidoEdit.contactoEmail;
    _contactoDireccionCtrl.text = _contenidoEdit.contactoDireccion;
    _contactoMapsUrlCtrl.text = _contenidoEdit.contactoMapsUrl;
    _contactoHorarioCtrl.text = _contenidoEdit.contactoHorario;
    _avisoLegalActualizadoCtrl.text = _contenidoEdit.avisoLegalActualizado;
  }

  Future<void> _guardarContenido() async {
    _contenidoEdit.nombreNegocio = _nombreNegocioCtrl.text.trim();
    _contenidoEdit.heroTitulo = _heroTituloCtrl.text.trim();
    _contenidoEdit.heroSubtitulo = _heroSubtituloCtrl.text.trim();
    _contenidoEdit.heroBotonCatalogo = _heroBotonCatalogoCtrl.text.trim();
    _contenidoEdit.heroBotonContacto = _heroBotonContactoCtrl.text.trim();
    _contenidoEdit.heroEstadisticaProductosEtiqueta =
        _heroEstadisticaProductosEtiquetaCtrl.text.trim();
    _contenidoEdit.heroEstadisticaMarcasValor = _heroEstadisticaMarcasValorCtrl.text.trim();
    _contenidoEdit.heroEstadisticaMarcasEtiqueta =
        _heroEstadisticaMarcasEtiquetaCtrl.text.trim();
    _contenidoEdit.heroEstadisticaCategoriasValor =
        _heroEstadisticaCategoriasValorCtrl.text.trim();
    _contenidoEdit.heroEstadisticaCategoriasEtiqueta =
        _heroEstadisticaCategoriasEtiquetaCtrl.text.trim();
    _contenidoEdit.historiaKicker = _historiaKickerCtrl.text.trim();
    _contenidoEdit.serviciosKicker = _serviciosKickerCtrl.text.trim();
    _contenidoEdit.serviciosTitulo = _serviciosTituloCtrl.text.trim();
    _contenidoEdit.catalogoKicker = _catalogoKickerCtrl.text.trim();
    _contenidoEdit.catalogoTitulo = _catalogoTituloCtrl.text.trim();
    _contenidoEdit.catalogoBusquedaHint = _catalogoBusquedaHintCtrl.text.trim();
    _contenidoEdit.contactoKicker = _contactoKickerCtrl.text.trim();
    _contenidoEdit.contactoTitulo = _contactoTituloCtrl.text.trim();
    _contenidoEdit.footerDerechos = _footerDerechosCtrl.text.trim();
    _contenidoEdit.historiaTitulo = _historiaTituloCtrl.text.trim();
    _contenidoEdit.historiaTexto = _historiaTextoCtrl.text.trim();
    _contenidoEdit.contactoWhatsapp = _contactoWhatsappCtrl.text.trim();
    _contenidoEdit.contactoEmail = _contactoEmailCtrl.text.trim();
    _contenidoEdit.contactoDireccion = _contactoDireccionCtrl.text.trim();
    _contenidoEdit.contactoMapsUrl = _contactoMapsUrlCtrl.text.trim();
    _contenidoEdit.contactoHorario = _contactoHorarioCtrl.text.trim();
    _contenidoEdit.avisoLegalActualizado = _avisoLegalActualizadoCtrl.text.trim();

    setState(() {
      _guardandoContenido = true;
      _resultadoContenido = null;
    });
    try {
      final guardado = await ApiService.instance.guardarContenido(_contenidoEdit);
      setState(() {
        SiteContent.actual = guardado;
        _contenidoEdit = guardado.copiaProfunda();
        _sincronizarControladoresContenido();
        _resultadoContenido = 'Cambios guardados. El sitio público ya los muestra.';
        _resultadoContenidoEsError = false;
      });
    } catch (e) {
      setState(() {
        _resultadoContenido = 'No se pudo guardar: $e';
        _resultadoContenidoEsError = true;
      });
    } finally {
      if (mounted) setState(() => _guardandoContenido = false);
    }
  }

  void _cerrarSesion() {
    ApiService.instance.logoutAdmin();
    Navigator.of(context).pop();
  }

  String _fmtFecha(String iso) {
    final fecha = DateTime.tryParse(iso);
    if (fecha == null) return iso;
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _categoriaDe(int repuestoId) {
    final p = _stock.where((x) => x.id == repuestoId);
    return p.isEmpty ? 'Otros' : (p.first.categoria.isEmpty ? 'Otros' : p.first.categoria);
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esAngosto = ancho < 900;

    return Scaffold(
      backgroundColor: AppColors.paper,
      drawer: esAngosto ? Drawer(child: _buildSidebar()) : null,
      appBar: esAngosto
          ? AppBar(
              backgroundColor: AppColors.char,
              foregroundColor: Colors.white,
              title: const Text('Maykel Repuestos — Admin'),
            )
          : null,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No se pudo cargar el panel: $_error',
                            style: TextStyle(color: AppColors.bad)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _cargarTodo, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : Row(
                  children: [
                    if (!esAngosto) SizedBox(width: 240, child: _buildSidebar()),
                    Expanded(
                      child: Column(
                        children: [
                          if (!esAngosto) _buildTopbar(),
                          Expanded(child: _buildContenido()),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ---------------------------------------------------------------
  // Sidebar
  // ---------------------------------------------------------------

  Widget _buildSidebar() {
    return Container(
      color: AppColors.char,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/images/logo.jpg',
                      width: 38, height: 38, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('MAYKEL\nREPUESTOS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.15)),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: _secciones
                  .where((s) => s.permiso == null || _sesion.puede(s.permiso!))
                  .map((s) => _itemSidebar(s))
                  .toList(),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.red,
                child: Text(
                  _sesion.usuario.isNotEmpty ? _sesion.usuario[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(_sesion.usuario.isEmpty ? 'Admin' : _sesion.usuario,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text(_sesion.esSuperAdmin ? 'Propietario' : (_sesion.rolNombre ?? ''),
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
                onPressed: _cerrarSesion,
                tooltip: 'Cerrar sesión',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemSidebar(_Seccion s) {
    final activo = s.clave == _seccionActiva;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: activo ? AppColors.red : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() => _seccionActiva = s.clave);
            if (MediaQuery.of(context).size.width < 900) {
              Navigator.of(context).maybePop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(s.icono, size: 18, color: activo ? Colors.white : Colors.white60),
                const SizedBox(width: 12),
                Text(s.etiqueta,
                    style: TextStyle(
                        color: activo ? Colors.white : Colors.white60,
                        fontSize: 13.5,
                        fontWeight: activo ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Topbar
  // ---------------------------------------------------------------

  Widget _buildTopbar() {
    final seccion = _secciones.firstWhere((s) => s.clave == _seccionActiva);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Text(seccion.etiqueta,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.char)),
          const Spacer(),
          IconButton(
            onPressed: _cargarTodo,
            icon: const Icon(Icons.refresh, color: AppColors.steel),
            tooltip: 'Actualizar datos',
          ),
          const SizedBox(width: 4),
          Icon(Icons.notifications_none, color: AppColors.steel),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.paper2,
            child: Text(
              _sesion.usuario.isNotEmpty ? _sesion.usuario[0].toUpperCase() : 'A',
              style: const TextStyle(color: AppColors.char, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Contenido según sección
  // ---------------------------------------------------------------

  Widget _buildContenido() {
    switch (_seccionActiva) {
      case 'analitica':
        return _buildAnaliticaTab();
      case 'catalogo':
        return _buildCatalogoTab();
      case 'reservas':
        return _buildReservasTab();
      case 'stock':
        return _buildStockTab();
      case 'usuarios':
        return _buildUsuariosTab();
      case 'configuracion':
        return _buildConfiguracionTab();
      case 'inicio':
      default:
        return _buildInicioTab();
    }
  }

  // ---------------------------------------------------------------
  // Inicio
  // ---------------------------------------------------------------

  Widget _buildInicioTab() {
    final d = _dashboard;
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Hola, ${_sesion.usuario.isEmpty ? "administrador" : _sesion.usuario} 👋',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.char)),
          const SizedBox(height: 6),
          Text('Este es el resumen general de Maykel Repuestos.',
              style: TextStyle(color: AppColors.steel, fontSize: 13.5)),
          const SizedBox(height: 24),
          if (d != null)
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _kpiCard('${_stock.length}', 'Productos en catálogo', Icons.inventory_2_outlined),
                _kpiCard('${d.totalVentas}', 'Ventas registradas', Icons.point_of_sale_outlined),
                _kpiCard('${d.totalReservas}', 'Reservas totales', Icons.event_note_outlined),
                _kpiCard('${d.agotadosCount}', 'Productos agotados', Icons.report_outlined),
              ],
            ),
          const SizedBox(height: 28),
          Text('Accesos rápidos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _secciones
                .where((s) => s.clave != 'inicio' && (s.permiso == null || _sesion.puede(s.permiso!)))
                .map((s) => _accesoRapido(s))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _accesoRapido(_Seccion s) {
    return InkWell(
      onTap: () => setState(() => _seccionActiva = s.clave),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.paper2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(s.icono, color: AppColors.red),
            const SizedBox(height: 10),
            Text(s.etiqueta, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String valor, String etiqueta, IconData icono) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.paper2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.paper, borderRadius: BorderRadius.circular(8)),
            child: Icon(icono, color: AppColors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valor,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.char)),
                Text(etiqueta,
                    style: TextStyle(fontSize: 11, color: AppColors.steel), maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Analítica (dashboard con gráficos)
  // ---------------------------------------------------------------

  List<MapEntry<DateTime, num>> _ventasPorDia() {
    final hoy = DateTime.now();
    final dias = List.generate(
        14, (i) => DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: 13 - i)));
    final totalesPorDia = {for (final d in dias) d: 0.0};
    for (final v in _ventas) {
      final fecha = DateTime.tryParse(v.fecha);
      if (fecha == null) continue;
      final clave = DateTime(fecha.year, fecha.month, fecha.day);
      if (totalesPorDia.containsKey(clave)) {
        totalesPorDia[clave] = (totalesPorDia[clave] ?? 0) + v.total;
      }
    }
    return totalesPorDia.entries.toList();
  }

  Map<String, num> _montoPorCategoria() {
    final mapa = <String, num>{};
    for (final v in _ventas) {
      final cat = _categoriaDe(v.repuestoId);
      mapa[cat] = (mapa[cat] ?? 0) + v.total;
    }
    return mapa;
  }

  List<({String nombre, String sku, num cantidad})> _topDemanda() {
    final mapa = <String, ({String nombre, String sku, num cantidad})>{};
    void agregar(String sku, String nombre, num cantidad) {
      final actual = mapa[sku];
      mapa[sku] = (nombre: nombre, sku: sku, cantidad: (actual?.cantidad ?? 0) + cantidad);
    }

    for (final r in _reservas) {
      agregar(r.sku, r.producto, r.cantidad);
    }
    for (final v in _ventas) {
      agregar(v.sku, v.producto, v.cantidad);
    }
    final lista = mapa.values.toList()..sort((a, b) => b.cantidad.compareTo(a.cantidad));
    return lista.take(5).toList();
  }

  List<String> _insights() {
    final d = _dashboard;
    if (d == null) return [];
    final insights = <String>[];
    if (_stock.isNotEmpty) {
      final pctAgotado = (d.agotadosCount / _stock.length * 100).round();
      if (d.agotadosCount > 0) {
        insights.add('El $pctAgotado% de tu catálogo está agotado (${d.agotadosCount} productos). '
            'Revisa la pestaña Stock para reponerlos.');
      }
    }
    final porCategoria = _montoPorCategoria();
    if (porCategoria.isNotEmpty) {
      final top = porCategoria.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add('La categoría con más ventas es "${top.key}" (${formatCLP(top.value)}).');
    }
    if (d.reservasPendientes > 0) {
      insights.add('Tienes ${d.reservasPendientes} reserva(s) pendiente(s) de confirmar.');
    }
    if (d.stockBajoCount > 0) {
      insights.add('${d.stockBajoCount} producto(s) tienen stock bajo (3 unidades o menos).');
    }
    if (insights.isEmpty) {
      insights.add('Aún no hay suficientes datos para generar recomendaciones. '
          'Registra ventas y reservas para ver aquí análisis automáticos.');
    }
    return insights;
  }

  Widget _buildAnaliticaTab() {
    final d = _dashboard;
    if (d == null) return const SizedBox.shrink();

    final serieVentas = _ventasPorDia();
    final porCategoria = _montoPorCategoria();
    final top = _topDemanda();
    final agotadosConCategoria = d.agotados.take(5).toList();

    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _kpiCard('${d.totalVentas}', 'Ventas registradas', Icons.point_of_sale_outlined),
              _kpiCard(formatCLP(d.montoVentas), 'Monto vendido (CLP)', Icons.payments_outlined),
              _kpiCard('${d.totalReservas}', 'Reservas totales (${d.reservasPendientes} pend.)',
                  Icons.event_note_outlined),
              _kpiCard('${d.agotadosCount}', 'Productos agotados', Icons.report_outlined),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final dosColumnas = constraints.maxWidth > 800;
            final graficoLinea = _panel(
              titulo: 'Ventas de los últimos 14 días',
              alto: 280,
              child: serieVentas.every((e) => e.value == 0)
                  ? _sinDatos('Aún no hay ventas registradas en este período.')
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: (serieVentas.length / 5).ceilToDouble().clamp(1, 14).toDouble(),
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= serieVentas.length) return const SizedBox.shrink();
                                final fecha = serieVentas[i].key;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('${fecha.day}/${fecha.month}',
                                      style: TextStyle(fontSize: 10, color: AppColors.steel)),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) => Text(formatCLP(value),
                                  style: TextStyle(fontSize: 9, color: AppColors.steel)),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (int i = 0; i < serieVentas.length; i++)
                                FlSpot(i.toDouble(), serieVentas[i].value.toDouble()),
                            ],
                            isCurved: true,
                            color: AppColors.red,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                                show: true, color: AppColors.red.withOpacity(0.12)),
                          ),
                        ],
                      ),
                    ),
            );

            final graficoDona = _panel(
              titulo: 'Ventas por categoría',
              alto: 280,
              child: porCategoria.isEmpty
                  ? _sinDatos('Aún no hay ventas para mostrar por categoría.')
                  : Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 42,
                              sections: [
                                for (int i = 0; i < porCategoria.entries.length; i++)
                                  PieChartSectionData(
                                    value: porCategoria.values.elementAt(i).toDouble(),
                                    color: _colorSerie(i),
                                    title: '',
                                    radius: 46,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (int i = 0; i < porCategoria.entries.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                              color: _colorSerie(i), shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(porCategoria.keys.elementAt(i),
                                            style: const TextStyle(fontSize: 11),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            );

            if (dosColumnas) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: graficoLinea),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: graficoDona),
                ],
              );
            }
            return Column(children: [graficoLinea, const SizedBox(height: 16), graficoDona]);
          }),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final dosColumnas = constraints.maxWidth > 800;
            final tablaTop = _panel(
              titulo: 'Top 5 productos con mayor demanda',
              child: _tablaSimple(
                columnas: const ['Producto', 'SKU', 'Cantidad'],
                filas: top.isEmpty
                    ? [const ['Aún no hay datos suficientes.', '', '']]
                    : top.map((t) => [t.nombre, t.sku, '${t.cantidad}']).toList(),
              ),
            );
            final tablaAgotados = _panel(
              titulo: 'Productos sin stock (Top 5)',
              child: _tablaSimple(
                columnas: const ['Producto', 'Categoría'],
                filas: agotadosConCategoria.isEmpty
                    ? [const ['No hay productos agotados. 🎉', '']]
                    : agotadosConCategoria
                        .map((p) => [p.nombre, _categoriaDe(p.id)])
                        .toList(),
              ),
            );

            if (dosColumnas) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tablaTop),
                  const SizedBox(width: 16),
                  Expanded(child: tablaAgotados),
                ],
              );
            }
            return Column(children: [tablaTop, const SizedBox(height: 16), tablaAgotados]);
          }),
          const SizedBox(height: 16),
          _panel(
            titulo: 'Recomendaciones',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _insights()
                  .map((texto) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.yellow),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(texto,
                                    style: const TextStyle(fontSize: 13, height: 1.4))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorSerie(int i) {
    const colores = [
      AppColors.red,
      AppColors.yellow,
      AppColors.ok,
      Color(0xFF3B7DD8),
      Color(0xFF8E5FD8),
      AppColors.warn,
      AppColors.steel,
    ];
    return colores[i % colores.length];
  }

  Widget _panel({required String titulo, required Widget child, double? alto}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.paper2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 14),
          SizedBox(height: alto, child: child),
        ],
      ),
    );
  }

  Widget _sinDatos(String texto) {
    return Center(
      child: Text(texto, style: TextStyle(color: AppColors.steel, fontSize: 12.5)),
    );
  }

  Widget _tablaSimple({required List<String> columnas, required List<List<String>> filas}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columnas.map((c) => DataColumn(label: Text(c))).toList(),
        rows: filas
            .map((fila) => DataRow(cells: fila.map((c) => DataCell(Text(c))).toList()))
            .toList(),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Catálogo (vista de solo lectura para el admin)
  // ---------------------------------------------------------------

  Widget _buildCatalogoTab() {
    final termino = _busquedaCatalogo.trim().toLowerCase();
    final filtrados = _stock
        .where((p) =>
            termino.isEmpty ||
            p.nombre.toLowerCase().contains(termino) ||
            p.marca.toLowerCase().contains(termino) ||
            p.sku.toLowerCase().contains(termino))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nombre, marca o SKU...',
            ),
            onChanged: (v) => setState(() => _busquedaCatalogo = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.paper2),
              ),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('SKU')),
                      DataColumn(label: Text('Nombre')),
                      DataColumn(label: Text('Categoría')),
                      DataColumn(label: Text('Marca / Modelo')),
                      DataColumn(label: Text('Precio')),
                      DataColumn(label: Text('Stock')),
                    ],
                    rows: filtrados
                        .map((p) => DataRow(cells: [
                              DataCell(Text(p.sku,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                              DataCell(Text(p.nombre)),
                              DataCell(Text(p.categoria)),
                              DataCell(Text(p.modelo.isNotEmpty ? '${p.marca} · ${p.modelo}' : p.marca)),
                              DataCell(Text(formatCLP(p.precio))),
                              DataCell(Text('${p.stock}')),
                            ]))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Ventas (registro rápido, embebido en Stock por simplicidad de nav)
  // ---------------------------------------------------------------

  Widget _formularioVenta() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.paper2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registrar venta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<int>(
                  value: _ventaProductoId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Producto'),
                  items: _stock
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            enabled: p.stock > 0,
                            child: Text(
                              '${p.nombre} — ${p.stock <= 0 ? "Agotado" : "${p.stock} disp."}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _ventaProductoId = v),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _ventaCantidadCtrl,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _ventaClienteCtrl,
                  decoration: const InputDecoration(labelText: 'Cliente (opcional)'),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _ventaMetodoPagoCtrl,
                  decoration: const InputDecoration(labelText: 'Método de pago (opcional)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _registrandoVenta ? null : _registrarVenta,
            child: _registrandoVenta
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Registrar venta'),
          ),
          if (_resultadoVenta != null) ...[
            const SizedBox(height: 10),
            Text(_resultadoVenta!,
                style: TextStyle(
                    color: _resultadoVentaEsError ? AppColors.bad : AppColors.ok, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Future<void> _registrarVenta() async {
    final productoId = _ventaProductoId;
    final cantidad = int.tryParse(_ventaCantidadCtrl.text) ?? 0;
    if (productoId == null || cantidad < 1) {
      setState(() {
        _resultadoVenta = 'Selecciona un producto y una cantidad válida.';
        _resultadoVentaEsError = true;
      });
      return;
    }
    setState(() {
      _registrandoVenta = true;
      _resultadoVenta = null;
    });
    try {
      final venta = await ApiService.instance.registrarVenta(
        repuestoId: productoId,
        cantidad: cantidad,
        cliente: _ventaClienteCtrl.text.trim(),
        metodoPago: _ventaMetodoPagoCtrl.text.trim(),
      );
      _ventaCantidadCtrl.text = '1';
      _ventaClienteCtrl.clear();
      _ventaMetodoPagoCtrl.clear();
      setState(() {
        _resultadoVenta =
            'Venta registrada: ${venta.cantidad} × ${venta.producto} (${formatCLP(venta.total)})';
        _resultadoVentaEsError = false;
      });
      await _cargarTodo();
    } catch (e) {
      setState(() {
        _resultadoVenta = 'Error: $e';
        _resultadoVentaEsError = true;
      });
    } finally {
      if (mounted) setState(() => _registrandoVenta = false);
    }
  }

  Future<void> _descargarPdfVentas() async {
    final filas = _ventas
        .map((v) => [
              _fmtFecha(v.fecha),
              '${v.producto} (${v.sku})',
              '${v.cantidad}',
              formatCLP(v.total),
              v.cliente.isEmpty ? '—' : v.cliente,
              v.metodoPago.isEmpty ? '—' : v.metodoPago,
            ])
        .toList();
    await generarReportePdf(
      titulo: 'Reporte de Ventas',
      columnas: const ['Fecha', 'Producto', 'Cant.', 'Total', 'Cliente', 'Pago'],
      filas: filas,
    );
  }

  // ---------------------------------------------------------------
  // Reservas
  // ---------------------------------------------------------------

  Widget _buildReservasTab() {
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${_reservas.length} reserva(s) registradas',
                    style: TextStyle(color: AppColors.steel, fontSize: 13)),
              ),
              OutlinedButton.icon(
                onPressed: _descargarPdfReservas,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Descargar PDF'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.paper2),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Cliente')),
                  DataColumn(label: Text('Contacto')),
                  DataColumn(label: Text('Producto')),
                  DataColumn(label: Text('Cant.')),
                  DataColumn(label: Text('Estado')),
                ],
                rows: _reservas.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('Aún no hay reservas.')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                        ])
                      ]
                    : _reservas
                        .map((r) => DataRow(cells: [
                              DataCell(Text(_fmtFecha(r.fecha))),
                              DataCell(Text(r.nombre)),
                              DataCell(Text('${r.telefono}\n${r.email}')),
                              DataCell(Text('${r.producto}\n${r.sku}')),
                              DataCell(Text('${r.cantidad}')),
                              DataCell(_estadoDropdown(r)),
                            ]))
                        .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoDropdown(Reserva r) {
    return DropdownButton<String>(
      value: r.estado,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
        DropdownMenuItem(value: 'confirmada', child: Text('Confirmada')),
        DropdownMenuItem(value: 'entregada', child: Text('Entregada')),
      ],
      onChanged: (nuevoEstado) async {
        if (nuevoEstado == null) return;
        try {
          await ApiService.instance.actualizarEstadoReserva(r.id, nuevoEstado);
          setState(() {
            final indice = _reservas.indexWhere((x) => x.id == r.id);
            if (indice >= 0) {
              _reservas[indice] = Reserva(
                id: r.id,
                fecha: r.fecha,
                repuestoId: r.repuestoId,
                sku: r.sku,
                producto: r.producto,
                cantidad: r.cantidad,
                nombre: r.nombre,
                telefono: r.telefono,
                email: r.email,
                nota: r.nota,
                estado: nuevoEstado,
              );
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Estado de la reserva actualizado.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo actualizar: $e')),
            );
          }
        }
      },
    );
  }

  Future<void> _descargarPdfReservas() async {
    final filas = _reservas
        .map((r) => [
              _fmtFecha(r.fecha),
              r.nombre,
              '${r.telefono} / ${r.email}',
              '${r.producto} (${r.sku})',
              '${r.cantidad}',
              r.estado,
            ])
        .toList();
    await generarReportePdf(
      titulo: 'Reporte de Reservas',
      columnas: const ['Fecha', 'Cliente', 'Contacto', 'Producto', 'Cant.', 'Estado'],
      filas: filas,
    );
  }

  // ---------------------------------------------------------------
  // Stock (incluye el registro de ventas y la descarga de PDF de ventas)
  // ---------------------------------------------------------------

  Widget _buildStockTab() {
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _formularioVenta(),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Precio y stock', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _mostrarFormProducto(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar producto'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _descargarPdfStock,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Stock en PDF'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _descargarPdfVentas,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Ventas en PDF'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _guardandoStock ? null : _guardarStock,
                child: _guardandoStock
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.paper2),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Nombre')),
                  DataColumn(label: Text('Categoría')),
                  DataColumn(label: Text('Precio')),
                  DataColumn(label: Text('Stock')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('')),
                ],
                rows: _stock.map((p) => _filaStock(p)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _filaStock(Repuesto p) {
    final precioCtrl = _precioCtrls[p.id]!;
    final stockCtrl = _stockCtrls[p.id]!;

    return DataRow(cells: [
      DataCell(Text(p.sku, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
      DataCell(Text(p.nombre)),
      DataCell(Text(p.categoria)),
      DataCell(
        SizedBox(
          width: 100,
          child: TextField(
            controller: precioCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      DataCell(
        SizedBox(
          width: 80,
          child: TextField(
            controller: stockCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
      DataCell(_estadoStockBadge(int.tryParse(stockCtrl.text) ?? 0)),
      DataCell(
        IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.bad),
          tooltip: 'Eliminar producto',
          onPressed: () => _eliminarProducto(p),
        ),
      ),
    ]);
  }

  Widget _estadoStockBadge(int stock) {
    late final Color color;
    late final String texto;
    if (stock <= 0) {
      color = AppColors.bad;
      texto = 'Agotado';
    } else if (stock <= 3) {
      color = AppColors.warn;
      texto = 'Stock bajo';
    } else {
      color = AppColors.ok;
      texto = 'Disponible';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(texto,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _guardarStock() async {
    setState(() => _guardandoStock = true);
    try {
      final cambios = _stock
          .map((p) {
            final precio = int.tryParse(_precioCtrls[p.id]!.text) ?? 0;
            final stock = int.tryParse(_stockCtrls[p.id]!.text) ?? 0;
            return <String, num>{
              'id': p.id,
              'precio': precio < 0 ? 0 : precio,
              'stock': stock < 0 ? 0 : stock,
            };
          })
          .toList();

      await ApiService.instance.guardarCambiosStock(cambios);
      await _cargarTodo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock y precios actualizados.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoStock = false);
    }
  }

  Future<void> _descargarPdfStock() async {
    final filas = _stock
        .map((p) => [
              p.sku,
              p.nombre,
              p.categoria,
              '${p.marca} ${p.modelo}'.trim(),
              formatCLP(p.precio),
              '${p.stock}',
            ])
        .toList();
    await generarReportePdf(
      titulo: 'Reporte de Stock',
      columnas: const ['SKU', 'Nombre', 'Categoría', 'Marca / Modelo', 'Precio', 'Stock'],
      filas: filas,
    );
  }

  Future<void> _mostrarFormProducto() async {
    final nombreCtrl = TextEditingController();
    final categoriaCtrl = TextEditingController();
    final marcaCtrl = TextEditingController();
    final modeloCtrl = TextEditingController();
    final precioCtrl = TextEditingController(text: '0');
    final stockCtrl = TextEditingController(text: '0');
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nuevo producto',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoriaCtrl,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: marcaCtrl,
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modeloCtrl,
                      decoration: const InputDecoration(labelText: 'Modelo'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: precioCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Precio'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Stock'),
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: TextStyle(color: AppColors.bad, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: guardando
                              ? null
                              : () async {
                                  if (nombreCtrl.text.trim().isEmpty) {
                                    setDialogState(() => error = 'El nombre es obligatorio.');
                                    return;
                                  }
                                  setDialogState(() {
                                    guardando = true;
                                    error = null;
                                  });
                                  try {
                                    await ApiService.instance.crearProducto(
                                      nombre: nombreCtrl.text.trim(),
                                      categoria: categoriaCtrl.text.trim(),
                                      marca: marcaCtrl.text.trim(),
                                      modelo: modeloCtrl.text.trim(),
                                      precio: num.tryParse(precioCtrl.text.trim()) ?? 0,
                                      stock: num.tryParse(stockCtrl.text.trim()) ?? 0,
                                    );
                                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                                    await _cargarTodo();
                                  } catch (e) {
                                    setDialogState(() {
                                      guardando = false;
                                      error = '$e';
                                    });
                                  }
                                },
                          child: guardando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Crear'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarProducto(Repuesto p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${p.nombre}" (${p.sku})? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.bad)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService.instance.eliminarProducto(p.id);
      await _cargarTodo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // ---------------------------------------------------------------
  // Usuarios (roles y cuentas del panel admin)
  // ---------------------------------------------------------------

  Widget _buildUsuariosTab() {
    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Crea roles con permisos específicos y luego asigna esos roles a las '
                  'personas de tu equipo que necesiten acceso al panel.',
                  style: TextStyle(color: AppColors.steel, fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Roles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _mostrarFormRol(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo rol'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _tablaRoles(),
          const SizedBox(height: 30),
          Row(
            children: [
              Text('Usuarios del panel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _roles.isEmpty ? null : () => _mostrarFormUsuario(),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Nuevo usuario'),
              ),
            ],
          ),
          if (_roles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Crea al menos un rol antes de agregar usuarios.',
                  style: TextStyle(color: AppColors.steel, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          _tablaUsuarios(),
        ],
      ),
    );
  }

  String _nombreRol(int rolId) {
    final r = _roles.where((x) => x.id == rolId);
    return r.isEmpty ? 'Rol eliminado' : r.first.nombre;
  }

  Widget _tablaRoles() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.paper2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 48,
          dataRowMaxHeight: 96,
          columns: const [
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Permisos')),
            DataColumn(label: Text('')),
          ],
          rows: _roles.isEmpty
              ? [
                  const DataRow(cells: [
                    DataCell(Text('Aún no has creado ningún rol.')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                  ])
                ]
              : _roles
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(SizedBox(
                          width: 340,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: r.permisos
                                .map((p) => Chip(
                                      label: Text(kNombrePermiso[p] ?? p,
                                          style: const TextStyle(fontSize: 10.5)),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: AppColors.paper,
                                    ))
                                .toList(),
                          ),
                        )),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _mostrarFormRol(rol: r),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: AppColors.bad),
                              onPressed: () => _eliminarRol(r),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        )),
                      ]))
                  .toList(),
        ),
      ),
    );
  }

  Widget _tablaUsuarios() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.paper2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Usuario')),
            DataColumn(label: Text('Nombre')),
            DataColumn(label: Text('Rol')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('')),
          ],
          rows: _usuariosAdmin.isEmpty
              ? [
                  const DataRow(cells: [
                    DataCell(Text('Aún no has creado usuarios adicionales.')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                  ])
                ]
              : _usuariosAdmin
                  .map((u) => DataRow(cells: [
                        DataCell(Text(u.usuario)),
                        DataCell(Text(u.nombre.isEmpty ? '—' : u.nombre)),
                        DataCell(Text(_nombreRol(u.rolId))),
                        DataCell(Text(u.activo ? 'Activo' : 'Inactivo',
                            style: TextStyle(color: u.activo ? AppColors.ok : AppColors.steel))),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _mostrarFormUsuario(usuario: u),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: AppColors.bad),
                              onPressed: () => _eliminarUsuario(u),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        )),
                      ]))
                  .toList(),
        ),
      ),
    );
  }

  Future<void> _mostrarFormRol({Rol? rol}) async {
    final nombreCtrl = TextEditingController(text: rol?.nombre ?? '');
    final permisosSeleccionados = <String>{...(rol?.permisos ?? [])};
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rol == null ? 'Nuevo rol' : 'Editar rol',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del rol'),
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Permisos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ),
                    ...kPermisosDisponibles.map((p) => CheckboxListTile(
                          value: permisosSeleccionados.contains(p),
                          onChanged: (v) => setDialogState(() {
                            if (v == true) {
                              permisosSeleccionados.add(p);
                            } else {
                              permisosSeleccionados.remove(p);
                            }
                          }),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(kNombrePermiso[p] ?? p, style: const TextStyle(fontSize: 13)),
                        )),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(error!, style: TextStyle(color: AppColors.bad, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: guardando
                                ? null
                                : () async {
                                    if (nombreCtrl.text.trim().isEmpty) {
                                      setDialogState(() => error = 'El nombre es obligatorio.');
                                      return;
                                    }
                                    setDialogState(() {
                                      guardando = true;
                                      error = null;
                                    });
                                    try {
                                      if (rol == null) {
                                        await ApiService.instance.crearRol(
                                            nombreCtrl.text.trim(), permisosSeleccionados.toList());
                                      } else {
                                        await ApiService.instance.actualizarRol(
                                            rol.id, nombreCtrl.text.trim(), permisosSeleccionados.toList());
                                      }
                                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                                      await _cargarTodo();
                                    } catch (e) {
                                      setDialogState(() {
                                        guardando = false;
                                        error = '$e';
                                      });
                                    }
                                  },
                            child: guardando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarRol(Rol rol) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar rol'),
        content: Text('¿Eliminar el rol "${rol.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.bad)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService.instance.eliminarRol(rol.id);
      await _cargarTodo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _mostrarFormUsuario({UsuarioAdmin? usuario}) async {
    final usuarioCtrl = TextEditingController(text: usuario?.usuario ?? '');
    final nombreCtrl = TextEditingController(text: usuario?.nombre ?? '');
    final passwordCtrl = TextEditingController();
    int? rolSeleccionado = usuario?.rolId ?? (_roles.isNotEmpty ? _roles.first.id : null);
    bool activo = usuario?.activo ?? true;
    String? error;
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(usuario == null ? 'Nuevo usuario' : 'Editar usuario',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usuarioCtrl,
                      enabled: usuario == null,
                      decoration: const InputDecoration(labelText: 'Nombre de usuario'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre completo (opcional)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: usuario == null ? 'Contraseña' : 'Nueva contraseña (opcional)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: rolSeleccionado,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: _roles
                          .map((r) => DropdownMenuItem(value: r.id, child: Text(r.nombre)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => rolSeleccionado = v),
                    ),
                    if (usuario != null) ...[
                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: activo,
                        onChanged: (v) => setDialogState(() => activo = v),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Usuario activo', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(error!, style: TextStyle(color: AppColors.bad, fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: guardando
                                ? null
                                : () async {
                                    if (usuarioCtrl.text.trim().isEmpty) {
                                      setDialogState(() => error = 'El usuario es obligatorio.');
                                      return;
                                    }
                                    if (usuario == null && passwordCtrl.text.isEmpty) {
                                      setDialogState(() => error = 'La contraseña es obligatoria.');
                                      return;
                                    }
                                    if (rolSeleccionado == null) {
                                      setDialogState(() => error = 'Debes seleccionar un rol.');
                                      return;
                                    }
                                    setDialogState(() {
                                      guardando = true;
                                      error = null;
                                    });
                                    try {
                                      if (usuario == null) {
                                        await ApiService.instance.crearUsuarioAdmin(
                                          usuario: usuarioCtrl.text.trim(),
                                          password: passwordCtrl.text,
                                          rolId: rolSeleccionado!,
                                          nombre: nombreCtrl.text.trim(),
                                        );
                                      } else {
                                        await ApiService.instance.actualizarUsuarioAdmin(
                                          usuario.id,
                                          nombre: nombreCtrl.text.trim(),
                                          rolId: rolSeleccionado,
                                          password: passwordCtrl.text,
                                          activo: activo,
                                        );
                                      }
                                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                                      await _cargarTodo();
                                    } catch (e) {
                                      setDialogState(() {
                                        guardando = false;
                                        error = '$e';
                                      });
                                    }
                                  },
                            child: guardando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _eliminarUsuario(UsuarioAdmin usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar el acceso de "${usuario.usuario}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.bad)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService.instance.eliminarUsuarioAdmin(usuario.id);
      await _cargarTodo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // ---------------------------------------------------------------
  // Configuración
  // ---------------------------------------------------------------

  Widget _buildConfiguracionTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.paper2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.steel),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Edita aquí el contenido que ven tus clientes en el sitio público: '
                  'historia, servicios, contacto y aviso legal. Los cambios se aplican '
                  'de inmediato al guardar.',
                  style: TextStyle(color: AppColors.steel, fontSize: 12.5, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _guardandoContenido ? null : _guardarContenido,
              icon: _guardandoContenido
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar todos los cambios'),
            ),
            if (_resultadoContenido != null) ...[
              const SizedBox(width: 14),
              Expanded(
                child: Text(_resultadoContenido!,
                    style: TextStyle(
                        color: _resultadoContenidoEsError ? AppColors.bad : AppColors.ok,
                        fontSize: 12.5)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ---------- Textos generales / Portada (Hero) ----------
        _panel(
          titulo: 'Textos generales y portada (Hero)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nombreNegocioCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del negocio'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _heroTituloCtrl,
                decoration: const InputDecoration(
                    labelText: 'Título principal (portada)',
                    helperText: 'Usa un salto de línea para partirlo en dos líneas'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _heroSubtituloCtrl,
                decoration: const InputDecoration(labelText: 'Subtítulo (portada)'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heroBotonCatalogoCtrl,
                      decoration: const InputDecoration(labelText: 'Texto botón "Ver catálogo"'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heroBotonContactoCtrl,
                      decoration: const InputDecoration(labelText: 'Texto botón "Contáctanos"'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Estadísticas de la portada',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _heroEstadisticaProductosEtiquetaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Etiqueta de productos (el número se calcula solo)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heroEstadisticaMarcasValorCtrl,
                      decoration: const InputDecoration(labelText: 'Valor (marcas)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _heroEstadisticaMarcasEtiquetaCtrl,
                      decoration: const InputDecoration(labelText: 'Etiqueta (marcas)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heroEstadisticaCategoriasValorCtrl,
                      decoration: const InputDecoration(labelText: 'Valor (categorías)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _heroEstadisticaCategoriasEtiquetaCtrl,
                      decoration: const InputDecoration(labelText: 'Etiqueta (categorías)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- Encabezados de sección ----------
        _panel(
          titulo: 'Encabezados de sección',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _historiaKickerCtrl,
                decoration: const InputDecoration(labelText: 'Kicker de "Historia"'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _serviciosKickerCtrl,
                      decoration: const InputDecoration(labelText: 'Kicker de "Servicios"'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _serviciosTituloCtrl,
                      decoration: const InputDecoration(labelText: 'Título de "Servicios"'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _catalogoKickerCtrl,
                      decoration: const InputDecoration(labelText: 'Kicker de "Catálogo"'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _catalogoTituloCtrl,
                      decoration: const InputDecoration(labelText: 'Título de "Catálogo"'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _catalogoBusquedaHintCtrl,
                decoration: const InputDecoration(labelText: 'Texto de ayuda del buscador'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contactoKickerCtrl,
                      decoration: const InputDecoration(labelText: 'Kicker de "Contacto"'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _contactoTituloCtrl,
                      decoration: const InputDecoration(labelText: 'Título de "Contacto"'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _footerDerechosCtrl,
                decoration: const InputDecoration(
                    labelText: 'Texto de derechos en el pie de página',
                    helperText: 'Se muestra como: © 2026 <este texto>'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- Historia ----------
        _panel(
          titulo: 'Historia de la empresa',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _historiaTituloCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _historiaTextoCtrl,
                decoration: const InputDecoration(labelText: 'Texto'),
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Datos destacados (fichas)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _mostrarFormFicha(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              ..._contenidoEdit.historiaFichas.asMap().entries.map((entrada) {
                final i = entrada.key;
                final f = entrada.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(f.etiqueta, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(f.valor, style: const TextStyle(fontSize: 12.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _mostrarFormFicha(indice: i),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: AppColors.bad),
                        onPressed: () => setState(() => _contenidoEdit.historiaFichas.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- Servicios ----------
        _panel(
          titulo: 'Servicios',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Lo que se muestra en la sección "Servicios" del sitio.',
                        style: TextStyle(color: AppColors.steel, fontSize: 12.5)),
                  ),
                  TextButton.icon(
                    onPressed: () => _mostrarFormServicio(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              ..._contenidoEdit.servicios.asMap().entries.map((entrada) {
                final i = entrada.key;
                final s = entrada.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(s.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(s.descripcion, style: const TextStyle(fontSize: 12.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _mostrarFormServicio(indice: i),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: AppColors.bad),
                        onPressed: () => setState(() => _contenidoEdit.servicios.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- Contacto ----------
        _panel(
          titulo: 'Datos de contacto',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _contactoWhatsappCtrl,
                decoration: const InputDecoration(
                    labelText: 'WhatsApp (solo números, con código de país)',
                    hintText: '56912345678'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactoEmailCtrl,
                decoration: const InputDecoration(labelText: 'Correo de contacto'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactoDireccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactoMapsUrlCtrl,
                decoration: const InputDecoration(labelText: 'Enlace de Google Maps'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactoHorarioCtrl,
                decoration: const InputDecoration(labelText: 'Horario de atención'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---------- Aviso legal ----------
        _panel(
          titulo: 'Aviso legal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _avisoLegalActualizadoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Fecha de última actualización', hintText: 'septiembre de 2026'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Secciones', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _mostrarFormSeccionLegal(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar sección'),
                  ),
                ],
              ),
              ..._contenidoEdit.avisoLegalSecciones.asMap().entries.map((entrada) {
                final i = entrada.key;
                final s = entrada.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(s.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(s.texto,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _mostrarFormSeccionLegal(indice: i),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: AppColors.bad),
                        onPressed: () =>
                            setState(() => _contenidoEdit.avisoLegalSecciones.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ElevatedButton.icon(
            onPressed: _guardandoContenido ? null : _guardarContenido,
            icon: _guardandoContenido
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('Guardar todos los cambios'),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _mostrarFormFicha({int? indice}) async {
    final existente = indice != null ? _contenidoEdit.historiaFichas[indice] : null;
    final etiquetaCtrl = TextEditingController(text: existente?.etiqueta ?? '');
    final valorCtrl = TextEditingController(text: existente?.valor ?? '');

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(indice == null ? 'Nueva ficha' : 'Editar ficha'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: etiquetaCtrl,
                decoration: const InputDecoration(labelText: 'Etiqueta', hintText: 'Ej: Ubicación'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valorCtrl,
                decoration: const InputDecoration(labelText: 'Valor'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (guardar != true) return;
    if (etiquetaCtrl.text.trim().isEmpty || valorCtrl.text.trim().isEmpty) return;
    setState(() {
      final ficha = FichaHistoria(etiqueta: etiquetaCtrl.text.trim(), valor: valorCtrl.text.trim());
      if (indice == null) {
        _contenidoEdit.historiaFichas.add(ficha);
      } else {
        _contenidoEdit.historiaFichas[indice] = ficha;
      }
    });
  }

  Future<void> _mostrarFormServicio({int? indice}) async {
    final existente = indice != null ? _contenidoEdit.servicios[indice] : null;
    final tituloCtrl = TextEditingController(text: existente?.titulo ?? '');
    final descripcionCtrl = TextEditingController(text: existente?.descripcion ?? '');

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(indice == null ? 'Nuevo servicio' : 'Editar servicio'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (guardar != true) return;
    if (tituloCtrl.text.trim().isEmpty) return;
    setState(() {
      final servicio =
          ServicioItem(titulo: tituloCtrl.text.trim(), descripcion: descripcionCtrl.text.trim());
      if (indice == null) {
        _contenidoEdit.servicios.add(servicio);
      } else {
        _contenidoEdit.servicios[indice] = servicio;
      }
    });
  }

  Future<void> _mostrarFormSeccionLegal({int? indice}) async {
    final existente = indice != null ? _contenidoEdit.avisoLegalSecciones[indice] : null;
    final tituloCtrl = TextEditingController(text: existente?.titulo ?? '');
    final textoCtrl = TextEditingController(text: existente?.texto ?? '');
    final itemsCtrl = TextEditingController(text: (existente?.items ?? []).join('\n'));

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(indice == null ? 'Nueva sección' : 'Editar sección'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título', hintText: 'Ej: 4. Uso del sitio'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textoCtrl,
                  decoration: const InputDecoration(labelText: 'Texto'),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: itemsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Puntos en lista (opcional, uno por línea)'),
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Guardar')),
        ],
      ),
    );

    if (guardar != true) return;
    if (tituloCtrl.text.trim().isEmpty) return;
    setState(() {
      final items = itemsCtrl.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final seccion = SeccionLegal(
        titulo: tituloCtrl.text.trim(),
        texto: textoCtrl.text.trim(),
        items: items,
      );
      if (indice == null) {
        _contenidoEdit.avisoLegalSecciones.add(seccion);
      } else {
        _contenidoEdit.avisoLegalSecciones[indice] = seccion;
      }
    });
  }
}
