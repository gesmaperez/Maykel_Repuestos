// server.dart
//
// Backend del catálogo público de Maykel Repuestos, reescrito en Dart puro
// (paquete `shelf`), replicando exactamente la misma lógica y las mismas
// rutas que el server.js original en Node/Express:
// - Base de datos: un archivo JSON plano (catalogo_db.json). Sin
//   dependencias nativas/compiladas, así que corre igual en cualquier
//   sistema operativo con el SDK de Dart instalado.
// - API pública de solo lectura para el catálogo (categorías, marcas,
//   repuestos con filtros, estado).
// - Reservas: el público crea, el admin gestiona el estado.
// - Ventas: el admin las registra (ej. venta en mostrador), descuenta stock.
// - Panel admin: reservas, ventas, edición de precio/stock, dashboard.
// - Sirve además el build web de Flutter (../app/build/web) si existe, para
//   quedar todo en un solo servidor desplegable.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

// ---------- Rutas de archivos ----------

final String _dirBackend = p.dirname(p.dirname(Platform.script.toFilePath()));
late final String rutaDb = p.join(_dirBackend, 'catalogo_db.json');
late final String rutaCategorias = p.join(_dirBackend, 'categorias.json');
late final String rutaMarcas = p.join(_dirBackend, 'marcas.json');
late final String rutaBuildWeb =
    p.join(p.dirname(_dirBackend), 'app', 'build', 'web');

// ---------- Usuarios administradores ----------
// Se configuran como variable de entorno del sistema operativo (Dart no lee
// archivos .env por sí solo), en formato:
// ADMIN_USERS=admin:maykel2026,juan:clave123,maria:clave456
Map<String, String> cargarAdmins() {
  final crudo = Platform.environment['ADMIN_USERS'] ?? 'admin:maykel2026';
  final admins = <String, String>{};
  for (final par in crudo.split(',')) {
    final partes = par.split(':');
    if (partes.length < 2) continue;
    final usuario = partes[0].trim();
    final password = partes.sublist(1).join(':').trim();
    if (usuario.isNotEmpty && password.isNotEmpty) {
      admins[usuario] = password;
    }
  }
  return admins;
}

final Map<String, String> admins = cargarAdmins();

/// Todos los permisos que puede tener un rol. Cada uno controla una
/// sección del panel admin.
const List<String> permisosDisponibles = [
  'dashboard',
  'catalogo',
  'reservas',
  'stock',
  'usuarios',
  'configuracion',
];

// ---------- Helpers de respuesta JSON ----------

Response jsonResponse(Object? data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: {'Content-Type': 'application/json; charset=utf-8'},
  );
}

Response errorResponse(String mensaje, {int status = 400}) {
  return jsonResponse({'error': mensaje}, status: status);
}

// ---------- Middleware: CORS ----------

Middleware corsHeaders() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ...headers});
    };
  };
}

// ---------- Middleware: autenticación básica del panel admin ----------
//
// Hay dos formas de ser administrador:
// 1. Usuario definido en la variable de entorno ADMIN_USERS: siempre tiene
//    acceso total a todo el panel (es el usuario "dueño" del sitio).
// 2. Usuario creado desde el módulo de Usuarios/Roles del propio panel:
//    sus permisos dependen del rol que se le haya asignado.

Map<String, dynamic>? _autenticar(Request request) {
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Basic ')) return null;
  try {
    final credenciales =
        utf8.decode(base64.decode(authHeader.substring(6).trim()));
    final separador = credenciales.indexOf(':');
    if (separador < 0) return null;
    final usuario = credenciales.substring(0, separador);
    final password = credenciales.substring(separador + 1);

    if (admins[usuario] != null && admins[usuario] == password) {
      return {
        'usuario': usuario,
        'permisos': permisosDisponibles,
        'esSuperAdmin': true,
        'rolNombre': 'Propietario',
      };
    }

    final data = leerDB();
    final usuarios =
        List<Map<String, dynamic>>.from(data['usuariosAdmin'] as List? ?? []);
    final roles = List<Map<String, dynamic>>.from(data['roles'] as List? ?? []);

    final u = usuarios.firstWhere(
      (x) =>
          x['usuario'] == usuario &&
          x['password'] == password &&
          x['activo'] != false,
      orElse: () => {},
    );
    if (u.isNotEmpty) {
      final rol = roles.firstWhere((r) => r['id'] == u['rolId'], orElse: () => {});
      final permisos =
          rol.isNotEmpty ? List<String>.from(rol['permisos'] as List) : <String>[];
      return {
        'usuario': usuario,
        'permisos': permisos,
        'esSuperAdmin': false,
        'rolNombre': rol.isNotEmpty ? rol['nombre'] : null,
      };
    }
  } catch (_) {
    return null;
  }
  return null;
}

Middleware requiereAuth() {
  return (Handler innerHandler) {
    return (Request request) async {
      final sesion = _autenticar(request);
      if (sesion != null) {
        final actualizado = request.change(context: {'adminSesion': sesion});
        return innerHandler(actualizado);
      }
      return Response(
        401,
        body: 'Acceso restringido. Ingresa un usuario y contraseña '
            'válidos del panel de administración.',
        headers: {
          'WWW-Authenticate':
              'Basic realm="Panel administrador Maykel Repuestos"',
        },
      );
    };
  };
}

// ---------- 1. "Base de datos" en JSON ----------
// Estructura: { categorias, marcas, repuestos: [...], reservas: [...],
//               ventas: [...] }

Map<String, dynamic> leerDB() {
  final archivo = File(rutaDb);
  if (!archivo.existsSync()) {
    return {
      'categorias': [],
      'marcas': [],
      'repuestos': [],
      'reservas': [],
      'ventas': [],
      'roles': [],
      'usuariosAdmin': [],
      'contenido': contenidoPorDefecto(),
    };
  }
  final data =
      jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
  data['reservas'] ??= [];
  data['ventas'] ??= [];
  data['roles'] ??= [];
  data['usuariosAdmin'] ??= [];
  data['contenido'] ??= contenidoPorDefecto();
  return data;
}

/// Contenido editable del sitio público (historia, servicios, contacto y
/// aviso legal), con los mismos textos que traía el sitio originalmente.
/// El administrador puede editar todo esto desde el panel, en la pestaña
/// Configuración.
Map<String, dynamic> contenidoPorDefecto() {
  return {
    'textos': {
      'nombreNegocio': 'MAYKEL REPUESTOS',
      'heroTitulo': 'REPUESTOS QUE\nMUEVEN CALAMA',
      'heroSubtitulo': 'Repuestos originales y alternativos para tu vehículo, con stock '
          'real y atención cercana en Calama. Consulta disponibilidad y '
          'reserva en línea.',
      'heroBotonCatalogo': 'Ver catálogo',
      'heroBotonContacto': 'Contáctanos',
      'heroEstadisticaProductosEtiqueta': 'Productos en catálogo',
      'heroEstadisticaMarcasValor': '46',
      'heroEstadisticaMarcasEtiqueta': 'Marcas disponibles',
      'heroEstadisticaCategoriasValor': '130',
      'heroEstadisticaCategoriasEtiqueta': 'Categorías',
      'historiaKicker': 'NUESTRA HISTORIA',
      'serviciosKicker': 'QUÉ OFRECEMOS',
      'serviciosTitulo': 'Servicios',
      'catalogoKicker': 'CATÁLOGO',
      'catalogoTitulo': 'Busca tu repuesto',
      'catalogoBusquedaHint': 'Buscar por nombre, marca o SKU...',
      'contactoKicker': 'CONTACTO',
      'contactoTitulo': 'Habla con nosotros',
      'footerDerechos': 'Maykel Repuestos. Todos los derechos reservados.',
    },
    'historia': {
      'titulo': 'Más de una década sirviendo a Calama',
      'texto': 'Maykel Repuestos nació para dar respuesta rápida y confiable a '
          'quienes necesitan mantener su vehículo funcionando: talleres, '
          'transportistas y particulares de Calama y la Región de '
          'Antofagasta. Trabajamos con proveedores nacionales y de '
          'importación para ofrecer repuestos originales y alternativos '
          'de calidad, con stock real y precios claros.',
      'fichas': [
        {'etiqueta': 'Ubicación', 'valor': 'Calama, Región de Antofagasta'},
        {'etiqueta': 'Especialidad', 'valor': 'Repuestos para autos y camionetas'},
        {'etiqueta': 'Stock', 'valor': 'Actualizado en línea, en tiempo real'},
        {'etiqueta': 'Atención', 'valor': 'Presencial, WhatsApp y correo'},
      ],
    },
    'servicios': [
      {
        'titulo': 'Venta de repuestos',
        'descripcion': 'Amplio catálogo de repuestos originales y alternativos.'
      },
      {
        'titulo': 'Asesoría técnica',
        'descripcion': 'Te ayudamos a encontrar la pieza correcta para tu vehículo.'
      },
      {
        'titulo': 'Reserva en línea',
        'descripcion': 'Reserva tu repuesto y retíralo o coordina despacho.'
      },
      {
        'titulo': 'Atención a talleres',
        'descripcion': 'Precios y stock pensados para talleres y transportistas.'
      },
    ],
    'contacto': {
      'whatsapp': '56969170551',
      'email': 'gesma.perez@gmail.com',
      'direccion': 'Vargas 2228-A, Calama, Región de Antofagasta',
      'mapsUrl':
          'https://www.google.com/maps/place/Maykel+Repuestos/@-22.4608953,-68.9286172,21z/data=!4m6!3m5!1s0x4ab51954d66992f7:0x3daf1bf514abec72!8m2!3d-22.4607923!4d-68.9285291',
      'horario': 'Lunes a viernes, 9:30 – 19:00\nSábado, 9:30 – 14:00',
    },
    'avisoLegal': {
      'actualizado': 'septiembre de 2026',
      'secciones': [
        {
          'titulo': '1. Identificación',
          'texto': 'Este sitio web es operado por Maykel Repuestos, negocio dedicado '
              'a la venta de repuestos automotrices, con domicilio en Vargas '
              '2228-A, Calama, Región de Antofagasta, Chile. Para consultas '
              'sobre este aviso legal, puedes escribir a gesma.perez@gmail.com.',
          'items': [],
        },
        {
          'titulo': '2. Objeto del sitio',
          'texto': 'Este sitio permite consultar el catálogo de repuestos '
              'disponibles y generar una solicitud de reserva sobre un '
              'producto. La reserva no constituye una compra confirmada ni '
              'un contrato de compraventa: es una manifestación de interés '
              'que debe ser confirmada directamente con el negocio por '
              'WhatsApp o correo electrónico, donde también se coordina el '
              'precio final, la forma de pago y la entrega o retiro del '
              'producto.',
          'items': [],
        },
        {
          'titulo': '3. Disponibilidad de stock y precios',
          'texto': 'El stock mostrado se actualiza periódicamente y puede no '
              'reflejar la disponibilidad exacta en todo momento. Los '
              'precios y condiciones de venta se informan directamente al '
              'cliente al confirmar la reserva, y pueden variar respecto a '
              'versiones anteriores del catálogo. Maykel Repuestos no '
              'garantiza la disponibilidad de un producto reservado hasta '
              'que la reserva sea confirmada por el negocio.',
          'items': [],
        },
        {
          'titulo': '4. Uso del sitio',
          'texto': 'Al usar este sitio, el usuario se compromete a:',
          'items': [
            'Proporcionar información veraz al momento de generar una reserva '
                '(nombre, teléfono, correo).',
            'No utilizar el sitio con fines fraudulentos, abusivos o contrarios a la ley.',
            'No intentar acceder sin autorización a áreas restringidas del sitio '
                '(como el panel de administración).',
          ],
        },
        {
          'titulo': '5. Protección de datos personales',
          'texto': 'Los datos que entregas al reservar un producto (nombre, '
              'teléfono, correo electrónico, y el comentario opcional) se '
              'utilizan exclusivamente para gestionar tu solicitud y '
              'contactarte respecto a ella. No se venden ni se comparten con '
              'terceros para fines comerciales ajenos a este propósito. De '
              'acuerdo con la Ley N° 19.628 sobre Protección de la Vida '
              'Privada, puedes solicitar en cualquier momento el acceso, '
              'rectificación o eliminación de tus datos escribiendo a '
              'gesma.perez@gmail.com.',
          'items': [],
        },
        {
          'titulo': '6. Propiedad intelectual',
          'texto': 'Los contenidos de este sitio (textos, nombre comercial, '
              'logotipo y diseño) pertenecen a Maykel Repuestos. No está '
              'permitida su reproducción o uso comercial sin autorización '
              'previa.',
          'items': [],
        },
        {
          'titulo': '7. Limitación de responsabilidad',
          'texto': 'Maykel Repuestos no se responsabiliza por errores u '
              'omisiones en la información publicada, ni por interrupciones '
              'temporales del sitio por mantenimiento o causas ajenas a su '
              'control. La compatibilidad de un repuesto con un vehículo '
              'específico debe confirmarse siempre con el negocio antes de '
              'la compra.',
          'items': [],
        },
        {
          'titulo': '8. Modificaciones',
          'texto': 'Este aviso legal puede actualizarse en cualquier momento '
              'para reflejar cambios en el funcionamiento del sitio o en la '
              'normativa aplicable. La versión vigente es siempre la '
              'publicada en esta página.',
          'items': [],
        },
        {
          'titulo': '9. Contacto',
          'texto': 'Para cualquier consulta sobre este aviso legal, tus datos '
              'o el funcionamiento del sitio, puedes escribir a '
              'gesma.perez@gmail.com o por WhatsApp al +56 9 6917 0551.',
          'items': [],
        },
      ],
    },
  };
}

void guardarDB(Map<String, dynamic> data) {
  // Escribe a un archivo temporal y luego renombra, para evitar corromper
  // el archivo si el proceso se interrumpe a mitad de la escritura.
  final temp = File('$rutaDb.tmp');
  temp.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(data),
    encoding: utf8,
  );
  temp.renameSync(rutaDb);
}

// ---------- 2. Semilla inicial: categorías, marcas reales y productos ----------

void inicializarDB() {
  if (File(rutaDb).existsSync()) return; // ya existe, no la pisamos

  List<dynamic> categorias = [];
  List<dynamic> marcas = [];
  final archCategorias = File(rutaCategorias);
  final archMarcas = File(rutaMarcas);
  if (archCategorias.existsSync()) {
    categorias = jsonDecode(archCategorias.readAsStringSync());
  }
  if (archMarcas.existsSync()) {
    marcas = jsonDecode(archMarcas.readAsStringSync());
  }

  final repuestos = [
    {
      'id': 1,
      'nombre': 'Pastillas de freno delanteras',
      'categoria': 'Pastillas de freno',
      'marca': 'Toyota',
      'modelo': 'Yaris',
      'precio': 24990,
      'stock': 15,
      'es_ejemplo': true,
    },
    {
      'id': 2,
      'nombre': 'Filtro de aceite',
      'categoria': 'Filtro aceite',
      'marca': 'Chevrolet',
      'modelo': 'Sail',
      'precio': 5990,
      'stock': 55,
      'es_ejemplo': true,
    },
    {
      'id': 3,
      'nombre': 'Amortiguador delantero',
      'categoria': 'Amortiguadores delanteros',
      'marca': 'Nissan',
      'modelo': 'Versa',
      'precio': 45990,
      'stock': 6,
      'es_ejemplo': true,
    },
    {
      'id': 4,
      'nombre': 'Batería 12V 60Ah',
      'categoria': 'BATERIAS',
      'marca': 'Universal',
      'modelo': 'Universal',
      'precio': 69990,
      'stock': 13,
      'es_ejemplo': true,
    },
    {
      'id': 5,
      'nombre': 'Disco de freno trasero',
      'categoria': 'Disco de freno',
      'marca': 'Hyundai',
      'modelo': 'Accent',
      'precio': 32990,
      'stock': 7,
      'es_ejemplo': true,
    },
  ];

  // Roles por defecto, para que el módulo de Usuarios no aparezca vacío.
  // "Propietario" (ADMIN_USERS) siempre tiene acceso total y no depende de
  // estos roles; estos son para el resto del equipo.
  final roles = [
    {
      'id': 1,
      'nombre': 'Administrador',
      'permisos': List<String>.from(permisosDisponibles),
    },
    {
      'id': 2,
      'nombre': 'Vendedor',
      'permisos': ['dashboard', 'catalogo', 'reservas', 'stock'],
    },
  ];

  guardarDB({
    'categorias': categorias,
    'marcas': marcas,
    'repuestos': repuestos,
    'reservas': [],
    'ventas': [],
    'roles': roles,
    'usuariosAdmin': [],
    'contenido': contenidoPorDefecto(),
  });
}

// ---------- Helpers de dominio ----------

String skuDe(Map<String, dynamic> p) {
  if (p['sku'] != null && (p['sku'] as String).isNotEmpty) {
    return p['sku'] as String;
  }
  final id = p['id'].toString().padLeft(4, '0');
  return 'REP-$id';
}

int _comparaEs(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

Future<Map<String, dynamic>?> _leerJsonBody(Request request) async {
  final texto = await request.readAsString();
  if (texto.isEmpty) return {};
  try {
    return jsonDecode(texto) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

num _numDe(dynamic v, [num porDefecto = 0]) {
  if (v == null) return porDefecto;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? porDefecto;
}

// ---------- 3. Rutas de la API ----------

final _router = Router()
  // -- Catálogo público --
  ..get('/api/categorias', (Request req) {
    final data = leerDB();
    final categorias = List<String>.from(data['categorias'] as List)
      ..sort(_comparaEs);
    return jsonResponse(categorias);
  })
  ..get('/api/marcas', (Request req) {
    final data = leerDB();
    final marcas = List<String>.from(data['marcas'] as List)..sort(_comparaEs);
    return jsonResponse(marcas);
  })
  ..get('/api/repuestos', (Request req) {
    final params = req.url.queryParameters;
    final buscar = params['buscar'];
    final categoria = params['categoria'];
    final marca = params['marca'];
    final disponible = params['disponible'];

    final data = leerDB();
    var repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);

    if (buscar != null && buscar.isNotEmpty) {
      final texto = buscar.toLowerCase();
      repuestos = repuestos
          .where((p) =>
              (p['nombre'] as String).toLowerCase().contains(texto))
          .toList();
    }
    if (categoria != null && categoria.isNotEmpty) {
      repuestos = repuestos.where((p) => p['categoria'] == categoria).toList();
    }
    if (marca != null && marca.isNotEmpty) {
      repuestos = repuestos.where((p) => p['marca'] == marca).toList();
    }
    if (disponible == '1') {
      repuestos = repuestos.where((p) => _numDe(p['stock']) > 0).toList();
    }

    repuestos.sort(
        (a, b) => _comparaEs(a['nombre'] as String, b['nombre'] as String));
    return jsonResponse(repuestos);
  })
  ..get('/api/estado', (Request req) {
    final data = leerDB();
    final repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);
    final total = repuestos.length;
    final ejemplo =
        repuestos.where((p) => p['es_ejemplo'] == true).length;
    return jsonResponse({
      'esDatosDeEjemplo': total > 0 && ejemplo == total,
      'totalProductos': total,
    });
  })

  // -- Contenido editable del sitio (historia, servicios, contacto, aviso legal) --
  // Público: cualquiera puede leerlo, para que se muestre en el sitio.
  ..get('/api/contenido', (Request req) {
    final data = leerDB();
    return jsonResponse(data['contenido'] ?? contenidoPorDefecto());
  })
  // Admin: solo un usuario con permiso 'configuracion' puede editarlo
  // (la ruta ya requiere estar autenticado; el chequeo de permiso se hace
  // también en el cliente, ocultando la sección a quien no lo tenga).
  ..put('/api/admin/contenido', (Request req) async {
    final body = await _leerJsonBody(req);
    if (body == null) return errorResponse('JSON inválido');

    final data = leerDB();
    data['contenido'] = body;
    guardarDB(data);
    return jsonResponse(data['contenido']);
  })

  // -- Reservas (público crea, admin gestiona) --
  ..post('/api/reservas', (Request req) async {
    final body = await _leerJsonBody(req);
    if (body == null) return errorResponse('JSON inválido');

    final repuestoId = body['repuestoId'];
    final nombre = body['nombre'];
    final telefono = body['telefono'];
    final email = body['email'];
    final cantidad = body['cantidad'];

    if (repuestoId == null ||
        nombre == null ||
        telefono == null ||
        email == null ||
        cantidad == null) {
      return errorResponse('Faltan datos obligatorios para la reserva');
    }

    final data = leerDB();
    final repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);
    final idBuscado = _numDe(repuestoId).toInt();
    final indice = repuestos.indexWhere((p) => _numDe(p['id']).toInt() == idBuscado);
    if (indice < 0) return errorResponse('El producto ya no existe', status: 404);

    final repuesto = repuestos[indice];
    final stockTotal = _numDe(repuesto['stock']);
    final qty = _numDe(cantidad).toInt();
    if (qty < 1 || qty > stockTotal) {
      return errorResponse('Cantidad no disponible en stock');
    }

    repuesto['stock'] = stockTotal - qty;

    final reserva = {
      'id': 'R${DateTime.now().millisecondsSinceEpoch}',
      'fecha': DateTime.now().toIso8601String(),
      'repuestoId': repuesto['id'],
      'sku': skuDe(repuesto),
      'producto': repuesto['nombre'],
      'cantidad': qty,
      'nombre': (nombre as String).trim(),
      'telefono': (telefono as String).trim(),
      'email': (email as String).trim(),
      'nota': body['nota'] != null ? (body['nota'] as String).trim() : '',
      'estado': 'pendiente',
    };

    final reservas = List<dynamic>.from(data['reservas'] as List);
    reservas.insert(0, reserva);
    data['reservas'] = reservas;
    data['repuestos'] = repuestos;
    guardarDB(data);

    return jsonResponse(reserva, status: 201);
  })
  ..get('/api/admin/reservas', (Request req) {
    final data = leerDB();
    return jsonResponse(data['reservas']);
  })
  ..put('/api/admin/reservas/<id>', (Request req, String id) async {
    final body = await _leerJsonBody(req);
    final estado = body?['estado'];
    const validos = ['pendiente', 'confirmada', 'entregada'];
    if (estado == null || !validos.contains(estado)) {
      return errorResponse('Estado inválido');
    }
    final data = leerDB();
    final reservas = List<Map<String, dynamic>>.from(data['reservas'] as List);
    final indice = reservas.indexWhere((r) => r['id'] == id);
    if (indice < 0) return errorResponse('Reserva no encontrada', status: 404);
    reservas[indice]['estado'] = estado;
    data['reservas'] = reservas;
    guardarDB(data);
    return jsonResponse(reservas[indice]);
  })

  // -- Edición masiva de precio/stock (pestaña "Stock") --
  ..put('/api/admin/repuestos', (Request req) async {
    final body = await _leerJsonBody(req);
    final cambios = body?['cambios'];
    if (cambios is! List) return errorResponse('Formato inválido');

    final data = leerDB();
    final repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);
    for (final cambioRaw in cambios) {
      final cambio = cambioRaw as Map<String, dynamic>;
      final id = _numDe(cambio['id']).toInt();
      final indice = repuestos.indexWhere((p) => _numDe(p['id']).toInt() == id);
      if (indice < 0) continue;
      if (cambio['precio'] != null) {
        final precio = _numDe(cambio['precio']);
        repuestos[indice]['precio'] = precio < 0 ? 0 : precio;
      }
      if (cambio['stock'] != null) {
        final stock = _numDe(cambio['stock']);
        repuestos[indice]['stock'] = stock < 0 ? 0 : stock;
      }
    }
    data['repuestos'] = repuestos;
    guardarDB(data);
    return jsonResponse({'ok': true});
  })

  // -- Crear un producto nuevo en el catálogo (pestaña Stock) --
  ..post('/api/admin/repuestos', (Request req) async {
    final body = await _leerJsonBody(req);
    if (body == null) return errorResponse('JSON inválido');

    final nombre = body['nombre'];
    if (nombre == null || (nombre as String).trim().isEmpty) {
      return errorResponse('El nombre del producto es obligatorio');
    }

    final data = leerDB();
    final repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);
    final siguienteId = repuestos.isEmpty
        ? 1
        : repuestos.map((p) => _numDe(p['id']).toInt()).reduce((a, b) => a > b ? a : b) + 1;

    final nuevo = {
      'id': siguienteId,
      'nombre': nombre.trim(),
      'categoria': body['categoria'] != null ? (body['categoria'] as String).trim() : '',
      'marca': body['marca'] != null ? (body['marca'] as String).trim() : '',
      'modelo': body['modelo'] != null ? (body['modelo'] as String).trim() : '',
      'precio': _numDe(body['precio']) < 0 ? 0 : _numDe(body['precio']),
      'stock': _numDe(body['stock']) < 0 ? 0 : _numDe(body['stock']),
      'es_ejemplo': false,
    };
    repuestos.add(nuevo);
    data['repuestos'] = repuestos;

    // Si la categoría o marca es nueva, se agrega también a las listas del
    // catálogo público (para que aparezca como filtro).
    final categorias = List<String>.from(data['categorias'] as List? ?? []);
    if (nuevo['categoria'] != '' && !categorias.contains(nuevo['categoria'])) {
      categorias.add(nuevo['categoria'] as String);
      data['categorias'] = categorias;
    }
    final marcas = List<String>.from(data['marcas'] as List? ?? []);
    if (nuevo['marca'] != '' && !marcas.contains(nuevo['marca'])) {
      marcas.add(nuevo['marca'] as String);
      data['marcas'] = marcas;
    }

    guardarDB(data);
    return jsonResponse(nuevo, status: 201);
  })

  // -- Eliminar un producto del catálogo --
  ..delete('/api/admin/repuestos/<id>', (Request req, String id) {
    final data = leerDB();
    final repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);
    final idNum = int.tryParse(id);
    final existia = repuestos.any((p) => _numDe(p['id']).toInt() == idNum);
    if (!existia) return errorResponse('Producto no encontrado', status: 404);
    repuestos.removeWhere((p) => _numDe(p['id']).toInt() == idNum);
    data['repuestos'] = repuestos;
    guardarDB(data);
    return jsonResponse({'ok': true});
  })

  // -- Login / verificación --
  ..get('/api/admin/verificar', (Request req) {
    final sesion = req.context['adminSesion'] as Map<String, dynamic>?;
    return jsonResponse({
      'ok': true,
      'usuario': sesion?['usuario'],
      'permisos': sesion?['permisos'],
      'esSuperAdmin': sesion?['esSuperAdmin'],
      'rolNombre': sesion?['rolNombre'],
    });
  })

  // -- Roles (módulo de Usuarios) --
  ..get('/api/admin/roles', (Request req) {
    final data = leerDB();
    return jsonResponse(data['roles']);
  })
  ..post('/api/admin/roles', (Request req) async {
    final body = await _leerJsonBody(req);
    final nombre = body?['nombre'];
    final permisos = body?['permisos'];
    if (nombre == null || (nombre as String).trim().isEmpty) {
      return errorResponse('El nombre del rol es obligatorio');
    }
    if (permisos is! List) return errorResponse('Formato de permisos inválido');

    final data = leerDB();
    final roles = List<Map<String, dynamic>>.from(data['roles'] as List);
    final siguienteId = roles.isEmpty
        ? 1
        : roles.map((r) => _numDe(r['id']).toInt()).reduce((a, b) => a > b ? a : b) + 1;

    final rol = {
      'id': siguienteId,
      'nombre': nombre.trim(),
      'permisos': permisos
          .map((p) => p.toString())
          .where((p) => permisosDisponibles.contains(p))
          .toList(),
    };
    roles.add(rol);
    data['roles'] = roles;
    guardarDB(data);
    return jsonResponse(rol, status: 201);
  })
  ..put('/api/admin/roles/<id>', (Request req, String id) async {
    final body = await _leerJsonBody(req);
    final data = leerDB();
    final roles = List<Map<String, dynamic>>.from(data['roles'] as List);
    final idNum = int.tryParse(id);
    final indice = roles.indexWhere((r) => _numDe(r['id']).toInt() == idNum);
    if (indice < 0) return errorResponse('Rol no encontrado', status: 404);

    if (body?['nombre'] != null && (body!['nombre'] as String).trim().isNotEmpty) {
      roles[indice]['nombre'] = (body['nombre'] as String).trim();
    }
    if (body?['permisos'] is List) {
      roles[indice]['permisos'] = (body!['permisos'] as List)
          .map((p) => p.toString())
          .where((p) => permisosDisponibles.contains(p))
          .toList();
    }
    data['roles'] = roles;
    guardarDB(data);
    return jsonResponse(roles[indice]);
  })
  ..delete('/api/admin/roles/<id>', (Request req, String id) {
    final data = leerDB();
    final roles = List<Map<String, dynamic>>.from(data['roles'] as List);
    final idNum = int.tryParse(id);
    final usuarios =
        List<Map<String, dynamic>>.from(data['usuariosAdmin'] as List);
    final enUso = usuarios.any((u) => _numDe(u['rolId']).toInt() == idNum);
    if (enUso) {
      return errorResponse(
          'No se puede eliminar: hay usuarios con este rol asignado.');
    }
    roles.removeWhere((r) => _numDe(r['id']).toInt() == idNum);
    data['roles'] = roles;
    guardarDB(data);
    return jsonResponse({'ok': true});
  })

  // -- Usuarios administradores (módulo de Usuarios) --
  ..get('/api/admin/usuarios', (Request req) {
    final data = leerDB();
    final usuarios =
        List<Map<String, dynamic>>.from(data['usuariosAdmin'] as List);
    // Nunca se devuelve la contraseña al listar.
    final sinPassword =
        usuarios.map((u) => {...u}..remove('password')).toList();
    return jsonResponse(sinPassword);
  })
  ..post('/api/admin/usuarios', (Request req) async {
    final body = await _leerJsonBody(req);
    final usuario = body?['usuario'];
    final password = body?['password'];
    final rolId = body?['rolId'];
    final nombre = body?['nombre'];
    if (usuario == null || (usuario as String).trim().isEmpty) {
      return errorResponse('El usuario es obligatorio');
    }
    if (password == null || (password as String).isEmpty) {
      return errorResponse('La contraseña es obligatoria');
    }
    if (rolId == null) return errorResponse('Debes asignar un rol');

    final data = leerDB();
    final usuarios =
        List<Map<String, dynamic>>.from(data['usuariosAdmin'] as List);
    if (usuarios.any((u) => u['usuario'] == usuario.trim())) {
      return errorResponse('Ese nombre de usuario ya existe');
    }
    final roles = List<Map<String, dynamic>>.from(data['roles'] as List);
    if (!roles.any((r) => _numDe(r['id']).toInt() == _numDe(rolId).toInt())) {
      return errorResponse('El rol seleccionado no existe');
    }

    final siguienteId = usuarios.isEmpty
        ? 1
        : usuarios.map((u) => _numDe(u['id']).toInt()).reduce((a, b) => a > b ? a : b) +
            1;

    final nuevo = {
      'id': siguienteId,
      'usuario': usuario.trim(),
      'password': password,
      'nombre': nombre != null ? (nombre as String).trim() : '',
      'rolId': _numDe(rolId).toInt(),
      'activo': true,
    };
    usuarios.add(nuevo);
    data['usuariosAdmin'] = usuarios;
    guardarDB(data);
    return jsonResponse({...nuevo}..remove('password'), status: 201);
  })
  ..put('/api/admin/usuarios/<id>', (Request req, String id) async {
    final body = await _leerJsonBody(req);
    final data = leerDB();
    final usuarios =
        List<Map<String, dynamic>>.from(data['usuariosAdmin'] as List);
    final idNum = int.tryParse(id);
    final indice = usuarios.indexWhere((u) => _numDe(u['id']).toInt() == idNum);
    if (indice < 0) return errorResponse('Usuario no encontrado', status: 404);

    if (body?['nombre'] != null) {
      usuarios[indice]['nombre'] = (body!['nombre'] as String).trim();
    }
    if (body?['rolId'] != null) {
      usuarios[indice]['rolId'] = _numDe(body!['rolId']).toInt();
    }
    if (body?['password'] != null && (body!['password'] as String).isNotEmpty) {
      usuarios[indice]['password'] = body['password'];
    }
    if (body?['activo'] != null) {
      usuarios[indice]['activo'] = body!['activo'] == true;
    }
    data['usuariosAdmin'] = usuarios;
    guardarDB(data);
    return jsonResponse({...usuarios[indice]}..remove('password'));
  })
  ..delete('/api/admin/usuarios/<id>', (Request req, String id) {
    final data = leerDB();
    final usuarios =
        List<Map<String, dynamic>>.from(data['usuariosAdmin'] as List);
    final idNum = int.tryParse(id);
    usuarios.removeWhere((u) => _numDe(u['id']).toInt() == idNum);
    data['usuariosAdmin'] = usuarios;
    guardarDB(data);
    return jsonResponse({'ok': true});
  })

  // -- Ventas (registradas por el administrador) --
  ..post('/api/admin/ventas', (Request req) async {
    final body = await _leerJsonBody(req);
    if (body == null) return errorResponse('JSON inválido');

    final repuestoId = body['repuestoId'];
    final cantidad = body['cantidad'];
    if (repuestoId == null || cantidad == null) {
      return errorResponse('Faltan datos: producto y cantidad son obligatorios');
    }

    final data = leerDB();
    final repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);
    final idBuscado = _numDe(repuestoId).toInt();
    final indice = repuestos.indexWhere((p) => _numDe(p['id']).toInt() == idBuscado);
    if (indice < 0) return errorResponse('El producto no existe', status: 404);

    final repuesto = repuestos[indice];
    final stockTotal = _numDe(repuesto['stock']);
    final qty = _numDe(cantidad).toInt();
    if (qty < 1 || qty > stockTotal) {
      return errorResponse('Cantidad no disponible en stock');
    }

    repuesto['stock'] = stockTotal - qty;
    final precio = _numDe(repuesto['precio']);

    final venta = {
      'id': 'V${DateTime.now().millisecondsSinceEpoch}',
      'fecha': DateTime.now().toIso8601String(),
      'repuestoId': repuesto['id'],
      'sku': skuDe(repuesto),
      'producto': repuesto['nombre'],
      'precio': precio,
      'cantidad': qty,
      'total': precio * qty,
      'cliente': body['cliente'] != null ? (body['cliente'] as String).trim() : '',
      'metodoPago':
          body['metodoPago'] != null ? (body['metodoPago'] as String).trim() : '',
      'nota': body['nota'] != null ? (body['nota'] as String).trim() : '',
    };

    final ventas = List<dynamic>.from(data['ventas'] as List);
    ventas.insert(0, venta);
    data['ventas'] = ventas;
    data['repuestos'] = repuestos;
    guardarDB(data);

    return jsonResponse(venta, status: 201);
  })
  ..get('/api/admin/ventas', (Request req) {
    final data = leerDB();
    return jsonResponse(data['ventas']);
  })

  // -- Dashboard --
  ..get('/api/admin/dashboard', (Request req) {
    final data = leerDB();
    final repuestos =
        List<Map<String, dynamic>>.from(data['repuestos'] as List);
    final reservas = List<Map<String, dynamic>>.from(data['reservas'] as List);
    final ventas = List<Map<String, dynamic>>.from(data['ventas'] as List);

    final totalVentas = ventas.length;
    final montoVentas =
        ventas.fold<num>(0, (s, v) => s + _numDe(v['total']));
    final totalReservas = reservas.length;
    final reservasPendientes =
        reservas.where((r) => r['estado'] == 'pendiente').length;
    final stockBajo = repuestos
        .where((p) => _numDe(p['stock']) <= 3 && _numDe(p['stock']) > 0)
        .toList();
    final agotados =
        repuestos.where((p) => _numDe(p['stock']) == 0).toList();

    return jsonResponse({
      'totalVentas': totalVentas,
      'montoVentas': montoVentas,
      'totalReservas': totalReservas,
      'reservasPendientes': reservasPendientes,
      'stockBajoCount': stockBajo.length,
      'agotadosCount': agotados.length,
      'stockBajo': stockBajo
          .map((p) => {'id': p['id'], 'nombre': p['nombre'], 'stock': p['stock']})
          .toList(),
      'agotados':
          agotados.map((p) => {'id': p['id'], 'nombre': p['nombre']}).toList(),
    });
  });

// Las rutas /api/admin/* requieren autenticación; el resto es público.
// En vez de armar un segundo router, se aplica un middleware que solo
// exige autenticación cuando la ruta empieza con /api/admin/.
Middleware _authSoloAdmin() {
  final authMw = requiereAuth();
  return (Handler innerHandler) {
    final protegido = authMw(innerHandler);
    return (Request request) async {
      if (request.url.path.startsWith('api/admin/')) {
        return protegido(request);
      }
      return innerHandler(request);
    };
  };
}

void main(List<String> args) async {
  inicializarDB();

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  Handler handler = _router.call;

  final buildWebDir = Directory(rutaBuildWeb);
  if (buildWebDir.existsSync()) {
    final staticHandler = createStaticHandler(
      rutaBuildWeb,
      defaultDocument: 'index.html',
    );
    handler = Cascade().add(handler).add(staticHandler).handler;
  }

  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(_authSoloAdmin())
      .addHandler(handler);

  final server = await shelf_io.serve(pipeline, InternetAddress.anyIPv4, port);
  print('Catálogo Maykel Repuestos (Dart) corriendo en '
      'http://${server.address.host}:${server.port}');
}
