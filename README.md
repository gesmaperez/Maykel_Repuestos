# Maykel Repuestos — Flutter + Dart

Catálogo público de repuestos y panel de administración de Maykel
Repuestos (Calama, Chile), reescrito completamente en **Flutter Web**
(frontend) y **Dart puro** (backend), sin ninguna dependencia nativa o
compilada — corre igual en Windows, macOS o Linux con solo los SDKs de
Flutter y Dart instalados.

Esta es la reescritura en Flutter/Dart de la versión anterior en
Node.js + HTML/JS. Mantiene exactamente el mismo diseño, flujo de uso y
reglas de negocio:

- Catálogo público con búsqueda y filtro por categoría.
- Reserva de productos (sin mostrar precio), con ticket para enviar por
  WhatsApp o correo.
- Panel de administración único, con 4 pestañas: **Dashboard**, **Ventas**,
  **Reservas** y **Stock**.
- Registro de ventas y reservas que descuenta stock automáticamente; el
  producto pasa a "Agotado" en el catálogo público cuando llega a 0.
- Gestión de productos desde el panel: **agregar y eliminar productos**
  del catálogo directamente desde la pestaña Stock, sin tocar el archivo
  de datos a mano.
- Descarga de reportes de ventas, reservas y **stock** en PDF.
- Aviso legal / términos de uso.
- Acceso al panel admin protegido con usuario y contraseña (varios
  administradores posibles).
- Panel admin con navegación lateral: Inicio, Analítica (gráficos), Catálogo,
  Reservas, Stock, Usuarios y Configuración.
- Módulo de **Usuarios y roles**: crear roles con permisos específicos y
  cuentas de acceso al panel para el equipo.
- **Todo el texto del sitio público es editable desde el panel** (pestaña
  Configuración): nombre del negocio, portada (título, subtítulo, botones
  y estadísticas), encabezados de cada sección, historia de la empresa,
  servicios, datos de contacto y aviso legal — todo se edita ahí y se
  guarda en el backend; el sitio público lo muestra al instante, sin
  tocar código ni volver a compilar.

## Estructura

```
maykel_flutter/
  backend/    — servidor Dart (shelf) con la API y la "base de datos" en JSON
  app/        — app Flutter Web (catálogo público + panel admin)
```

Cada carpeta tiene su propio `README.md` con instrucciones detalladas de
instalación y ejecución:

- [`backend/README.md`](backend/README.md)
- [`app/README.md`](app/README.md)

## Inicio rápido

```bash
# 1. Compila la app Flutter
cd app
flutter pub get
flutter build web

# 2. Corre el backend (sirve la API y la app compilada, todo en un puerto)
cd ../backend
dart pub get
dart run bin/server.dart
```

Abre `http://localhost:8080` en tu navegador.

