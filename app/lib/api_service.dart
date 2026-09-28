import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String mensaje;
  ApiException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Cliente HTTP para la API del backend. Guarda las credenciales del
/// administrador en memoria únicamente (se pierden al recargar la página,
/// igual que en la versión anterior en JavaScript).
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String? _authHeader;
  SesionAdmin? _sesion;

  bool get sesionAdminActiva => _authHeader != null;
  SesionAdmin? get sesion => _sesion;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$kApiBase$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool admin = false, bool json = false}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (admin && _authHeader != null) headers['Authorization'] = _authHeader!;
    return headers;
  }

  String? _mensajeError(http.Response resp) {
    try {
      final data = jsonDecode(resp.body);
      if (data is Map && data['error'] != null) return data['error'].toString();
    } catch (_) {
      // ignorar, no era JSON
    }
    return null;
  }

  // ---------- Catálogo público ----------

  Future<List<String>> getCategorias() async {
    final resp = await http.get(_uri('/api/categorias'));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudieron cargar las categorías.');
    }
    return List<String>.from(jsonDecode(resp.body) as List);
  }

  Future<List<String>> getMarcas() async {
    final resp = await http.get(_uri('/api/marcas'));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudieron cargar las marcas.');
    }
    return List<String>.from(jsonDecode(resp.body) as List);
  }

  Future<List<Repuesto>> getRepuestos({
    String? buscar,
    String? categoria,
    String? marca,
    bool soloDisponibles = false,
  }) async {
    final query = <String, String>{};
    if (buscar != null && buscar.isNotEmpty) query['buscar'] = buscar;
    if (categoria != null && categoria.isNotEmpty) query['categoria'] = categoria;
    if (marca != null && marca.isNotEmpty) query['marca'] = marca;
    if (soloDisponibles) query['disponible'] = '1';

    final resp = await http.get(_uri('/api/repuestos', query));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudieron cargar los repuestos.');
    }
    final lista = jsonDecode(resp.body) as List;
    return lista
        .map((e) => Repuesto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Reservas ----------

  Future<Reserva> crearReserva({
    required int repuestoId,
    required String nombre,
    required String telefono,
    required String email,
    required int cantidad,
    String nota = '',
  }) async {
    final resp = await http.post(
      _uri('/api/reservas'),
      headers: _headers(json: true),
      body: jsonEncode({
        'repuestoId': repuestoId,
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'cantidad': cantidad,
        'nota': nota,
      }),
    );
    if (resp.statusCode != 201) {
      throw ApiException(
          _mensajeError(resp) ?? 'No se pudo confirmar la reserva.');
    }
    return Reserva.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  // ---------- Admin: sesión ----------

  Future<bool> loginAdmin(String usuario, String password) async {
    final intento =
        'Basic ${base64Encode(utf8.encode('$usuario:$password'))}';
    final resp = await http.get(
      _uri('/api/admin/verificar'),
      headers: {'Authorization': intento},
    );
    if (resp.statusCode == 200) {
      _authHeader = intento;
      _sesion = SesionAdmin.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      return true;
    }
    return false;
  }

  void logoutAdmin() {
    _authHeader = null;
    _sesion = null;
  }

  // ---------- Admin: reservas ----------

  Future<List<Reserva>> getReservasAdmin() async {
    final resp =
        await http.get(_uri('/api/admin/reservas'), headers: _headers(admin: true));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudieron cargar las reservas.');
    }
    final lista = jsonDecode(resp.body) as List;
    return lista.map((e) => Reserva.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> actualizarEstadoReserva(String id, String estado) async {
    final resp = await http.put(
      _uri('/api/admin/reservas/$id'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode({'estado': estado}),
    );
    if (resp.statusCode != 200) {
      throw ApiException(
          _mensajeError(resp) ?? 'No se pudo actualizar la reserva.');
    }
  }

  // ---------- Admin: ventas ----------

  Future<Venta> registrarVenta({
    required int repuestoId,
    required int cantidad,
    String cliente = '',
    String metodoPago = '',
    String nota = '',
  }) async {
    final resp = await http.post(
      _uri('/api/admin/ventas'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode({
        'repuestoId': repuestoId,
        'cantidad': cantidad,
        'cliente': cliente,
        'metodoPago': metodoPago,
        'nota': nota,
      }),
    );
    if (resp.statusCode != 201) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo registrar la venta.');
    }
    return Venta.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<Venta>> getVentasAdmin() async {
    final resp =
        await http.get(_uri('/api/admin/ventas'), headers: _headers(admin: true));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudieron cargar las ventas.');
    }
    final lista = jsonDecode(resp.body) as List;
    return lista.map((e) => Venta.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ---------- Admin: stock/precio ----------

  Future<void> guardarCambiosStock(
      List<Map<String, num>> cambios) async {
    final resp = await http.put(
      _uri('/api/admin/repuestos'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode({'cambios': cambios}),
    );
    if (resp.statusCode != 200) {
      throw ApiException(
          _mensajeError(resp) ?? 'No se pudo guardar stock/precio.');
    }
  }

  Future<Repuesto> crearProducto({
    required String nombre,
    String categoria = '',
    String marca = '',
    String modelo = '',
    num precio = 0,
    num stock = 0,
  }) async {
    final resp = await http.post(
      _uri('/api/admin/repuestos'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode({
        'nombre': nombre,
        'categoria': categoria,
        'marca': marca,
        'modelo': modelo,
        'precio': precio,
        'stock': stock,
      }),
    );
    if (resp.statusCode != 201) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo crear el producto.');
    }
    return Repuesto.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> eliminarProducto(int id) async {
    final resp = await http.delete(
      _uri('/api/admin/repuestos/$id'),
      headers: _headers(admin: true),
    );
    if (resp.statusCode != 200) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo eliminar el producto.');
    }
  }

  // ---------- Admin: dashboard ----------

  Future<DashboardData> getDashboard() async {
    final resp = await http.get(_uri('/api/admin/dashboard'),
        headers: _headers(admin: true));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudo cargar el dashboard.');
    }
    return DashboardData.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  // ---------- Admin: roles ----------

  Future<List<Rol>> getRoles() async {
    final resp =
        await http.get(_uri('/api/admin/roles'), headers: _headers(admin: true));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudieron cargar los roles.');
    }
    final lista = jsonDecode(resp.body) as List;
    return lista.map((e) => Rol.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Rol> crearRol(String nombre, List<String> permisos) async {
    final resp = await http.post(
      _uri('/api/admin/roles'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode({'nombre': nombre, 'permisos': permisos}),
    );
    if (resp.statusCode != 201) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo crear el rol.');
    }
    return Rol.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Rol> actualizarRol(int id, String nombre, List<String> permisos) async {
    final resp = await http.put(
      _uri('/api/admin/roles/$id'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode({'nombre': nombre, 'permisos': permisos}),
    );
    if (resp.statusCode != 200) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo actualizar el rol.');
    }
    return Rol.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> eliminarRol(int id) async {
    final resp = await http.delete(
      _uri('/api/admin/roles/$id'),
      headers: _headers(admin: true),
    );
    if (resp.statusCode != 200) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo eliminar el rol.');
    }
  }

  // ---------- Admin: usuarios administradores ----------

  Future<List<UsuarioAdmin>> getUsuariosAdmin() async {
    final resp = await http.get(_uri('/api/admin/usuarios'),
        headers: _headers(admin: true));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudieron cargar los usuarios.');
    }
    final lista = jsonDecode(resp.body) as List;
    return lista.map((e) => UsuarioAdmin.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UsuarioAdmin> crearUsuarioAdmin({
    required String usuario,
    required String password,
    required int rolId,
    String nombre = '',
  }) async {
    final resp = await http.post(
      _uri('/api/admin/usuarios'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode({
        'usuario': usuario,
        'password': password,
        'rolId': rolId,
        'nombre': nombre,
      }),
    );
    if (resp.statusCode != 201) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo crear el usuario.');
    }
    return UsuarioAdmin.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> actualizarUsuarioAdmin(
    int id, {
    String? nombre,
    int? rolId,
    String? password,
    bool? activo,
  }) async {
    final body = <String, dynamic>{};
    if (nombre != null) body['nombre'] = nombre;
    if (rolId != null) body['rolId'] = rolId;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (activo != null) body['activo'] = activo;

    final resp = await http.put(
      _uri('/api/admin/usuarios/$id'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo actualizar el usuario.');
    }
  }

  Future<void> eliminarUsuarioAdmin(int id) async {
    final resp = await http.delete(
      _uri('/api/admin/usuarios/$id'),
      headers: _headers(admin: true),
    );
    if (resp.statusCode != 200) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo eliminar el usuario.');
    }
  }

  // ---------- Contenido editable del sitio ----------
  // Público (sin login): lo usa el sitio para mostrar historia, servicios,
  // contacto y aviso legal. Guardar sí requiere estar autenticado.

  Future<ContenidoSitio> getContenido() async {
    final resp = await http.get(_uri('/api/contenido'));
    if (resp.statusCode != 200) {
      throw ApiException('No se pudo cargar el contenido del sitio.');
    }
    return ContenidoSitio.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<ContenidoSitio> guardarContenido(ContenidoSitio contenido) async {
    final resp = await http.put(
      _uri('/api/admin/contenido'),
      headers: _headers(admin: true, json: true),
      body: jsonEncode(contenido.toJson()),
    );
    if (resp.statusCode != 200) {
      throw ApiException(_mensajeError(resp) ?? 'No se pudo guardar el contenido.');
    }
    return ContenidoSitio.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}
