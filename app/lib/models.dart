/// Modelos de datos del catálogo, reservas y ventas.
/// Reflejan exactamente la misma estructura JSON que entrega el backend.

/// Todos los permisos que puede tener un rol, en el orden en que se
/// muestran en el formulario de creación de roles. Deben coincidir
/// exactamente con `permisosDisponibles` del backend.
const List<String> kPermisosDisponibles = [
  'dashboard',
  'catalogo',
  'reservas',
  'stock',
  'usuarios',
  'configuracion',
];

/// Nombre legible de cada permiso, para mostrar en la interfaz.
const Map<String, String> kNombrePermiso = {
  'dashboard': 'Ver dashboard / analítica',
  'catalogo': 'Ver catálogo de productos',
  'reservas': 'Gestionar reservas',
  'stock': 'Gestionar precio y stock',
  'usuarios': 'Administrar usuarios y roles',
  'configuracion': 'Acceder a configuración',
};

class Repuesto {
  final int id;
  final String nombre;
  final String categoria;
  final String marca;
  final String modelo;
  final num precio;
  final num stock;
  final bool esEjemplo;

  Repuesto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.marca,
    required this.modelo,
    required this.precio,
    required this.stock,
    this.esEjemplo = false,
  });

  /// SKU calculado igual que en el backend: REP-0001, REP-0002, etc.
  String get sku => 'REP-${id.toString().padLeft(4, '0')}';

  factory Repuesto.fromJson(Map<String, dynamic> json) {
    return Repuesto(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
      marca: json['marca'] as String? ?? '',
      modelo: json['modelo'] as String? ?? '',
      precio: json['precio'] as num? ?? 0,
      stock: json['stock'] as num? ?? 0,
      esEjemplo: json['es_ejemplo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'categoria': categoria,
        'marca': marca,
        'modelo': modelo,
        'precio': precio,
        'stock': stock,
        'es_ejemplo': esEjemplo,
      };
}

/// Reserva creada por un cliente desde el catálogo público.
/// Nunca incluye precio ni total, por diseño del negocio.
class Reserva {
  final String id;
  final String fecha;
  final int repuestoId;
  final String sku;
  final String producto;
  final num cantidad;
  final String nombre;
  final String telefono;
  final String email;
  final String nota;
  final String estado; // pendiente | confirmada | entregada

  Reserva({
    required this.id,
    required this.fecha,
    required this.repuestoId,
    required this.sku,
    required this.producto,
    required this.cantidad,
    required this.nombre,
    required this.telefono,
    required this.email,
    required this.nota,
    required this.estado,
  });

  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      id: json['id'] as String,
      fecha: json['fecha'] as String,
      repuestoId: (json['repuestoId'] as num).toInt(),
      sku: json['sku'] as String? ?? '',
      producto: json['producto'] as String? ?? '',
      cantidad: json['cantidad'] as num? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      email: json['email'] as String? ?? '',
      nota: json['nota'] as String? ?? '',
      estado: json['estado'] as String? ?? 'pendiente',
    );
  }
}

/// Venta registrada por el administrador (ej. venta en mostrador).
class Venta {
  final String id;
  final String fecha;
  final int repuestoId;
  final String sku;
  final String producto;
  final num precio;
  final num cantidad;
  final num total;
  final String cliente;
  final String metodoPago;
  final String nota;

  Venta({
    required this.id,
    required this.fecha,
    required this.repuestoId,
    required this.sku,
    required this.producto,
    required this.precio,
    required this.cantidad,
    required this.total,
    required this.cliente,
    required this.metodoPago,
    required this.nota,
  });

  factory Venta.fromJson(Map<String, dynamic> json) {
    return Venta(
      id: json['id'] as String,
      fecha: json['fecha'] as String,
      repuestoId: (json['repuestoId'] as num).toInt(),
      sku: json['sku'] as String? ?? '',
      producto: json['producto'] as String? ?? '',
      precio: json['precio'] as num? ?? 0,
      cantidad: json['cantidad'] as num? ?? 0,
      total: json['total'] as num? ?? 0,
      cliente: json['cliente'] as String? ?? '',
      metodoPago: json['metodoPago'] as String? ?? '',
      nota: json['nota'] as String? ?? '',
    );
  }
}

/// Producto agregado en el resumen de agotados/stock bajo del dashboard.
class ProductoResumen {
  final int id;
  final String nombre;
  final num? stock;

  ProductoResumen({required this.id, required this.nombre, this.stock});

  factory ProductoResumen.fromJson(Map<String, dynamic> json) {
    return ProductoResumen(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? '',
      stock: json['stock'] as num?,
    );
  }
}

/// Datos agregados del dashboard del panel admin.
class DashboardData {
  final int totalVentas;
  final num montoVentas;
  final int totalReservas;
  final int reservasPendientes;
  final int stockBajoCount;
  final int agotadosCount;
  final List<ProductoResumen> stockBajo;
  final List<ProductoResumen> agotados;

  DashboardData({
    required this.totalVentas,
    required this.montoVentas,
    required this.totalReservas,
    required this.reservasPendientes,
    required this.stockBajoCount,
    required this.agotadosCount,
    required this.stockBajo,
    required this.agotados,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalVentas: (json['totalVentas'] as num?)?.toInt() ?? 0,
      montoVentas: json['montoVentas'] as num? ?? 0,
      totalReservas: (json['totalReservas'] as num?)?.toInt() ?? 0,
      reservasPendientes: (json['reservasPendientes'] as num?)?.toInt() ?? 0,
      stockBajoCount: (json['stockBajoCount'] as num?)?.toInt() ?? 0,
      agotadosCount: (json['agotadosCount'] as num?)?.toInt() ?? 0,
      stockBajo: (json['stockBajo'] as List<dynamic>? ?? [])
          .map((e) => ProductoResumen.fromJson(e as Map<String, dynamic>))
          .toList(),
      agotados: (json['agotados'] as List<dynamic>? ?? [])
          .map((e) => ProductoResumen.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Resultado de iniciar sesión como administrador: quién es y qué puede
/// ver/hacer en el panel, según su rol (o acceso total si es el
/// propietario definido en ADMIN_USERS).
class SesionAdmin {
  final String usuario;
  final List<String> permisos;
  final bool esSuperAdmin;
  final String? rolNombre;

  SesionAdmin({
    required this.usuario,
    required this.permisos,
    required this.esSuperAdmin,
    this.rolNombre,
  });

  bool puede(String permiso) => esSuperAdmin || permisos.contains(permiso);

  factory SesionAdmin.fromJson(Map<String, dynamic> json) {
    return SesionAdmin(
      usuario: json['usuario'] as String? ?? '',
      permisos: (json['permisos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      esSuperAdmin: json['esSuperAdmin'] as bool? ?? false,
      rolNombre: json['rolNombre'] as String?,
    );
  }
}

/// Un rol del panel admin: un nombre y el conjunto de permisos que otorga.
class Rol {
  final int id;
  final String nombre;
  final List<String> permisos;

  Rol({required this.id, required this.nombre, required this.permisos});

  factory Rol.fromJson(Map<String, dynamic> json) {
    return Rol(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String? ?? '',
      permisos: (json['permisos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Un usuario del panel admin creado desde el módulo de Usuarios, con un
/// rol asignado (distinto de los usuarios "propietario" de ADMIN_USERS).
class UsuarioAdmin {
  final int id;
  final String usuario;
  final String nombre;
  final int rolId;
  final bool activo;

  UsuarioAdmin({
    required this.id,
    required this.usuario,
    required this.nombre,
    required this.rolId,
    required this.activo,
  });

  factory UsuarioAdmin.fromJson(Map<String, dynamic> json) {
    return UsuarioAdmin(
      id: (json['id'] as num).toInt(),
      usuario: json['usuario'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      rolId: (json['rolId'] as num?)?.toInt() ?? 0,
      activo: json['activo'] as bool? ?? true,
    );
  }
}

// =====================================================================
// Contenido editable del sitio público: historia, servicios, contacto y
// aviso legal. El administrador lo edita desde la pestaña Configuración,
// y el sitio público lo lee vía GET /api/contenido (sin necesitar login).
// =====================================================================

class FichaHistoria {
  String etiqueta;
  String valor;

  FichaHistoria({required this.etiqueta, required this.valor});

  factory FichaHistoria.fromJson(Map<String, dynamic> json) => FichaHistoria(
        etiqueta: json['etiqueta'] as String? ?? '',
        valor: json['valor'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'etiqueta': etiqueta, 'valor': valor};
}

class ServicioItem {
  String titulo;
  String descripcion;

  ServicioItem({required this.titulo, required this.descripcion});

  factory ServicioItem.fromJson(Map<String, dynamic> json) => ServicioItem(
        titulo: json['titulo'] as String? ?? '',
        descripcion: json['descripcion'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'titulo': titulo, 'descripcion': descripcion};
}

class SeccionLegal {
  String titulo;
  String texto;
  List<String> items;

  SeccionLegal({required this.titulo, required this.texto, List<String>? items})
      : items = items ?? [];

  factory SeccionLegal.fromJson(Map<String, dynamic> json) => SeccionLegal(
        titulo: json['titulo'] as String? ?? '',
        texto: json['texto'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {'titulo': titulo, 'texto': texto, 'items': items};
}

/// Todo el contenido editable del sitio público, en un solo objeto que se
/// guarda y se lee de una sola vez.
class ContenidoSitio {
  String nombreNegocio;
  String heroTitulo;
  String heroSubtitulo;
  String heroBotonCatalogo;
  String heroBotonContacto;
  String heroEstadisticaProductosEtiqueta;
  String heroEstadisticaMarcasValor;
  String heroEstadisticaMarcasEtiqueta;
  String heroEstadisticaCategoriasValor;
  String heroEstadisticaCategoriasEtiqueta;
  String historiaKicker;
  String serviciosKicker;
  String serviciosTitulo;
  String catalogoKicker;
  String catalogoTitulo;
  String catalogoBusquedaHint;
  String contactoKicker;
  String contactoTitulo;
  String footerDerechos;
  String historiaTitulo;
  String historiaTexto;
  List<FichaHistoria> historiaFichas;
  List<ServicioItem> servicios;
  String contactoWhatsapp;
  String contactoEmail;
  String contactoDireccion;
  String contactoMapsUrl;
  String contactoHorario;
  String avisoLegalActualizado;
  List<SeccionLegal> avisoLegalSecciones;

  ContenidoSitio({
    required this.nombreNegocio,
    required this.heroTitulo,
    required this.heroSubtitulo,
    required this.heroBotonCatalogo,
    required this.heroBotonContacto,
    required this.heroEstadisticaProductosEtiqueta,
    required this.heroEstadisticaMarcasValor,
    required this.heroEstadisticaMarcasEtiqueta,
    required this.heroEstadisticaCategoriasValor,
    required this.heroEstadisticaCategoriasEtiqueta,
    required this.historiaKicker,
    required this.serviciosKicker,
    required this.serviciosTitulo,
    required this.catalogoKicker,
    required this.catalogoTitulo,
    required this.catalogoBusquedaHint,
    required this.contactoKicker,
    required this.contactoTitulo,
    required this.footerDerechos,
    required this.historiaTitulo,
    required this.historiaTexto,
    required this.historiaFichas,
    required this.servicios,
    required this.contactoWhatsapp,
    required this.contactoEmail,
    required this.contactoDireccion,
    required this.contactoMapsUrl,
    required this.contactoHorario,
    required this.avisoLegalActualizado,
    required this.avisoLegalSecciones,
  });

  /// Copia profunda, para editar en el panel admin sin tocar la copia que
  /// se está mostrando en el sitio hasta que se guarde.
  ContenidoSitio copiaProfunda() {
    return ContenidoSitio(
      nombreNegocio: nombreNegocio,
      heroTitulo: heroTitulo,
      heroSubtitulo: heroSubtitulo,
      heroBotonCatalogo: heroBotonCatalogo,
      heroBotonContacto: heroBotonContacto,
      heroEstadisticaProductosEtiqueta: heroEstadisticaProductosEtiqueta,
      heroEstadisticaMarcasValor: heroEstadisticaMarcasValor,
      heroEstadisticaMarcasEtiqueta: heroEstadisticaMarcasEtiqueta,
      heroEstadisticaCategoriasValor: heroEstadisticaCategoriasValor,
      heroEstadisticaCategoriasEtiqueta: heroEstadisticaCategoriasEtiqueta,
      historiaKicker: historiaKicker,
      serviciosKicker: serviciosKicker,
      serviciosTitulo: serviciosTitulo,
      catalogoKicker: catalogoKicker,
      catalogoTitulo: catalogoTitulo,
      catalogoBusquedaHint: catalogoBusquedaHint,
      contactoKicker: contactoKicker,
      contactoTitulo: contactoTitulo,
      footerDerechos: footerDerechos,
      historiaTitulo: historiaTitulo,
      historiaTexto: historiaTexto,
      historiaFichas: historiaFichas
          .map((f) => FichaHistoria(etiqueta: f.etiqueta, valor: f.valor))
          .toList(),
      servicios: servicios
          .map((s) => ServicioItem(titulo: s.titulo, descripcion: s.descripcion))
          .toList(),
      contactoWhatsapp: contactoWhatsapp,
      contactoEmail: contactoEmail,
      contactoDireccion: contactoDireccion,
      contactoMapsUrl: contactoMapsUrl,
      contactoHorario: contactoHorario,
      avisoLegalActualizado: avisoLegalActualizado,
      avisoLegalSecciones: avisoLegalSecciones
          .map((s) => SeccionLegal(titulo: s.titulo, texto: s.texto, items: List.from(s.items)))
          .toList(),
    );
  }

  factory ContenidoSitio.fromJson(Map<String, dynamic> json) {
    final textos = json['textos'] as Map<String, dynamic>? ?? {};
    final historia = json['historia'] as Map<String, dynamic>? ?? {};
    final contacto = json['contacto'] as Map<String, dynamic>? ?? {};
    final avisoLegal = json['avisoLegal'] as Map<String, dynamic>? ?? {};
    return ContenidoSitio(
      nombreNegocio: textos['nombreNegocio'] as String? ?? 'MAYKEL REPUESTOS',
      heroTitulo: textos['heroTitulo'] as String? ?? '',
      heroSubtitulo: textos['heroSubtitulo'] as String? ?? '',
      heroBotonCatalogo: textos['heroBotonCatalogo'] as String? ?? '',
      heroBotonContacto: textos['heroBotonContacto'] as String? ?? '',
      heroEstadisticaProductosEtiqueta:
          textos['heroEstadisticaProductosEtiqueta'] as String? ?? '',
      heroEstadisticaMarcasValor: textos['heroEstadisticaMarcasValor'] as String? ?? '',
      heroEstadisticaMarcasEtiqueta: textos['heroEstadisticaMarcasEtiqueta'] as String? ?? '',
      heroEstadisticaCategoriasValor: textos['heroEstadisticaCategoriasValor'] as String? ?? '',
      heroEstadisticaCategoriasEtiqueta:
          textos['heroEstadisticaCategoriasEtiqueta'] as String? ?? '',
      historiaKicker: textos['historiaKicker'] as String? ?? '',
      serviciosKicker: textos['serviciosKicker'] as String? ?? '',
      serviciosTitulo: textos['serviciosTitulo'] as String? ?? '',
      catalogoKicker: textos['catalogoKicker'] as String? ?? '',
      catalogoTitulo: textos['catalogoTitulo'] as String? ?? '',
      catalogoBusquedaHint: textos['catalogoBusquedaHint'] as String? ?? '',
      contactoKicker: textos['contactoKicker'] as String? ?? '',
      contactoTitulo: textos['contactoTitulo'] as String? ?? '',
      footerDerechos: textos['footerDerechos'] as String? ?? '',
      historiaTitulo: historia['titulo'] as String? ?? '',
      historiaTexto: historia['texto'] as String? ?? '',
      historiaFichas: (historia['fichas'] as List<dynamic>? ?? [])
          .map((e) => FichaHistoria.fromJson(e as Map<String, dynamic>))
          .toList(),
      servicios: (json['servicios'] as List<dynamic>? ?? [])
          .map((e) => ServicioItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      contactoWhatsapp: contacto['whatsapp'] as String? ?? '',
      contactoEmail: contacto['email'] as String? ?? '',
      contactoDireccion: contacto['direccion'] as String? ?? '',
      contactoMapsUrl: contacto['mapsUrl'] as String? ?? '',
      contactoHorario: contacto['horario'] as String? ?? '',
      avisoLegalActualizado: avisoLegal['actualizado'] as String? ?? '',
      avisoLegalSecciones: (avisoLegal['secciones'] as List<dynamic>? ?? [])
          .map((e) => SeccionLegal.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'textos': {
          'nombreNegocio': nombreNegocio,
          'heroTitulo': heroTitulo,
          'heroSubtitulo': heroSubtitulo,
          'heroBotonCatalogo': heroBotonCatalogo,
          'heroBotonContacto': heroBotonContacto,
          'heroEstadisticaProductosEtiqueta': heroEstadisticaProductosEtiqueta,
          'heroEstadisticaMarcasValor': heroEstadisticaMarcasValor,
          'heroEstadisticaMarcasEtiqueta': heroEstadisticaMarcasEtiqueta,
          'heroEstadisticaCategoriasValor': heroEstadisticaCategoriasValor,
          'heroEstadisticaCategoriasEtiqueta': heroEstadisticaCategoriasEtiqueta,
          'historiaKicker': historiaKicker,
          'serviciosKicker': serviciosKicker,
          'serviciosTitulo': serviciosTitulo,
          'catalogoKicker': catalogoKicker,
          'catalogoTitulo': catalogoTitulo,
          'catalogoBusquedaHint': catalogoBusquedaHint,
          'contactoKicker': contactoKicker,
          'contactoTitulo': contactoTitulo,
          'footerDerechos': footerDerechos,
        },
        'historia': {
          'titulo': historiaTitulo,
          'texto': historiaTexto,
          'fichas': historiaFichas.map((f) => f.toJson()).toList(),
        },
        'servicios': servicios.map((s) => s.toJson()).toList(),
        'contacto': {
          'whatsapp': contactoWhatsapp,
          'email': contactoEmail,
          'direccion': contactoDireccion,
          'mapsUrl': contactoMapsUrl,
          'horario': contactoHorario,
        },
        'avisoLegal': {
          'actualizado': avisoLegalActualizado,
          'secciones': avisoLegalSecciones.map((s) => s.toJson()).toList(),
        },
      };

  /// Contenido de referencia (el mismo texto original del sitio), usado
  /// mientras se carga el contenido real desde el backend o si esa carga
  /// falla por algún motivo.
  factory ContenidoSitio.porDefecto() {
    return ContenidoSitio(
      nombreNegocio: 'MAYKEL REPUESTOS',
      heroTitulo: 'REPUESTOS QUE\nMUEVEN CALAMA',
      heroSubtitulo: 'Repuestos originales y alternativos para tu vehículo, con stock '
          'real y atención cercana en Calama. Consulta disponibilidad y '
          'reserva en línea.',
      heroBotonCatalogo: 'Ver catálogo',
      heroBotonContacto: 'Contáctanos',
      heroEstadisticaProductosEtiqueta: 'Productos en catálogo',
      heroEstadisticaMarcasValor: '46',
      heroEstadisticaMarcasEtiqueta: 'Marcas disponibles',
      heroEstadisticaCategoriasValor: '130',
      heroEstadisticaCategoriasEtiqueta: 'Categorías',
      historiaKicker: 'NUESTRA HISTORIA',
      serviciosKicker: 'QUÉ OFRECEMOS',
      serviciosTitulo: 'Servicios',
      catalogoKicker: 'CATÁLOGO',
      catalogoTitulo: 'Busca tu repuesto',
      catalogoBusquedaHint: 'Buscar por nombre, marca o SKU...',
      contactoKicker: 'CONTACTO',
      contactoTitulo: 'Habla con nosotros',
      footerDerechos: 'Maykel Repuestos. Todos los derechos reservados.',
      historiaTitulo: 'Más de una década sirviendo a Calama',
      historiaTexto: 'Maykel Repuestos nació para dar respuesta rápida y confiable a '
          'quienes necesitan mantener su vehículo funcionando: talleres, '
          'transportistas y particulares de Calama y la Región de '
          'Antofagasta. Trabajamos con proveedores nacionales y de '
          'importación para ofrecer repuestos originales y alternativos '
          'de calidad, con stock real y precios claros.',
      historiaFichas: [
        FichaHistoria(etiqueta: 'Ubicación', valor: 'Calama, Región de Antofagasta'),
        FichaHistoria(etiqueta: 'Especialidad', valor: 'Repuestos para autos y camionetas'),
        FichaHistoria(etiqueta: 'Stock', valor: 'Actualizado en línea, en tiempo real'),
        FichaHistoria(etiqueta: 'Atención', valor: 'Presencial, WhatsApp y correo'),
      ],
      servicios: [
        ServicioItem(
            titulo: 'Venta de repuestos',
            descripcion: 'Amplio catálogo de repuestos originales y alternativos.'),
        ServicioItem(
            titulo: 'Asesoría técnica',
            descripcion: 'Te ayudamos a encontrar la pieza correcta para tu vehículo.'),
        ServicioItem(
            titulo: 'Reserva en línea',
            descripcion: 'Reserva tu repuesto y retíralo o coordina despacho.'),
        ServicioItem(
            titulo: 'Atención a talleres',
            descripcion: 'Precios y stock pensados para talleres y transportistas.'),
      ],
      contactoWhatsapp: '56969170551',
      contactoEmail: 'gesma.perez@gmail.com',
      contactoDireccion: 'Vargas 2228-A, Calama, Región de Antofagasta',
      contactoMapsUrl:
          'https://www.google.com/maps/place/Maykel+Repuestos/@-22.4608953,-68.9286172,21z/data=!4m6!3m5!1s0x4ab51954d66992f7:0x3daf1bf514abec72!8m2!3d-22.4607923!4d-68.9285291',
      contactoHorario: 'Lunes a viernes, 9:30 – 19:00\nSábado, 9:30 – 14:00',
      avisoLegalActualizado: 'septiembre de 2026',
      avisoLegalSecciones: [
        SeccionLegal(
          titulo: '1. Identificación',
          texto: 'Este sitio web es operado por Maykel Repuestos, negocio dedicado a la '
              'venta de repuestos automotrices, con domicilio en Vargas 2228-A, '
              'Calama, Región de Antofagasta, Chile. Para consultas sobre este '
              'aviso legal, puedes escribir a gesma.perez@gmail.com.',
        ),
        SeccionLegal(
          titulo: '2. Objeto del sitio',
          texto: 'Este sitio permite consultar el catálogo de repuestos disponibles y '
              'generar una solicitud de reserva sobre un producto. La reserva no '
              'constituye una compra confirmada ni un contrato de compraventa: es '
              'una manifestación de interés que debe ser confirmada directamente '
              'con el negocio por WhatsApp o correo electrónico, donde también se '
              'coordina el precio final, la forma de pago y la entrega o retiro '
              'del producto.',
        ),
        SeccionLegal(
          titulo: '3. Disponibilidad de stock y precios',
          texto: 'El stock mostrado se actualiza periódicamente y puede no reflejar la '
              'disponibilidad exacta en todo momento. Los precios y condiciones de '
              'venta se informan directamente al cliente al confirmar la reserva, '
              'y pueden variar respecto a versiones anteriores del catálogo. '
              'Maykel Repuestos no garantiza la disponibilidad de un producto '
              'reservado hasta que la reserva sea confirmada por el negocio.',
        ),
        SeccionLegal(
          titulo: '4. Uso del sitio',
          texto: 'Al usar este sitio, el usuario se compromete a:',
          items: [
            'Proporcionar información veraz al momento de generar una reserva '
                '(nombre, teléfono, correo).',
            'No utilizar el sitio con fines fraudulentos, abusivos o contrarios a la ley.',
            'No intentar acceder sin autorización a áreas restringidas del sitio '
                '(como el panel de administración).',
          ],
        ),
        SeccionLegal(
          titulo: '5. Protección de datos personales',
          texto: 'Los datos que entregas al reservar un producto (nombre, teléfono, '
              'correo electrónico, y el comentario opcional) se utilizan '
              'exclusivamente para gestionar tu solicitud y contactarte respecto a '
              'ella. No se venden ni se comparten con terceros para fines '
              'comerciales ajenos a este propósito. De acuerdo con la Ley N° '
              '19.628 sobre Protección de la Vida Privada, puedes solicitar en '
              'cualquier momento el acceso, rectificación o eliminación de tus '
              'datos escribiendo a gesma.perez@gmail.com.',
        ),
        SeccionLegal(
          titulo: '6. Propiedad intelectual',
          texto: 'Los contenidos de este sitio (textos, nombre comercial, logotipo y '
              'diseño) pertenecen a Maykel Repuestos. No está permitida su '
              'reproducción o uso comercial sin autorización previa.',
        ),
        SeccionLegal(
          titulo: '7. Limitación de responsabilidad',
          texto: 'Maykel Repuestos no se responsabiliza por errores u omisiones en la '
              'información publicada, ni por interrupciones temporales del sitio '
              'por mantenimiento o causas ajenas a su control. La compatibilidad '
              'de un repuesto con un vehículo específico debe confirmarse siempre '
              'con el negocio antes de la compra.',
        ),
        SeccionLegal(
          titulo: '8. Modificaciones',
          texto: 'Este aviso legal puede actualizarse en cualquier momento para '
              'reflejar cambios en el funcionamiento del sitio o en la normativa '
              'aplicable. La versión vigente es siempre la publicada en esta '
              'página.',
        ),
        SeccionLegal(
          titulo: '9. Contacto',
          texto: 'Para cualquier consulta sobre este aviso legal, tus datos o el '
              'funcionamiento del sitio, puedes escribir a gesma.perez@gmail.com '
              'o por WhatsApp al +56 9 6917 0551.',
        ),
      ],
    );
  }
}

/// Contenedor global con el contenido del sitio actualmente cargado. Se
/// actualiza apenas el sitio o el panel admin obtienen datos frescos del
/// backend, y todas las pantallas leen de aquí para no tener que pasar el
/// contenido manualmente entre widgets.
class SiteContent {
  static ContenidoSitio actual = ContenidoSitio.porDefecto();
}
