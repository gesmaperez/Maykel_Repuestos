# Backend — Maykel Repuestos (Dart)

Backend del catálogo de Maykel Repuestos, escrito en Dart puro con el
paquete [`shelf`](https://pub.dev/packages/shelf). No usa ninguna
dependencia nativa ni compilada, así que corre igual en Windows, macOS o
Linux con solo el [SDK de Dart](https://dart.dev/get-dart) instalado —
nada de Visual Studio, node-gyp, ni similares.

## Qué hace

- Sirve la API pública del catálogo (categorías, marcas, repuestos con
  filtros, estado).
- Recibe reservas del público y las guarda (sin precio, según las reglas
  del negocio).
- Permite al administrador registrar ventas, gestionar reservas, editar
  precio/stock, **agregar y eliminar productos** del catálogo, y ver un
  dashboard con totales.
- Guarda todo el contenido de texto del sitio público (nombre del
  negocio, portada, encabezados de sección, historia, servicios,
  contacto y aviso legal) en la base de datos, editable desde el panel.
- Protege todas las rutas `/api/admin/*` con autenticación básica
  (usuario + contraseña).
- Opcionalmente sirve el build web de Flutter (`../app/build/web`) como
  archivos estáticos, para quedar todo en **un solo servidor** desplegable.

## Requisitos

- [Dart SDK](https://dart.dev/get-dart) 3.0 o superior (no necesitas
  instalar Flutter para correr solo el backend).

## Instalación

```bash
cd backend
dart pub get
```

## Configuración (usuarios administradores y puerto)

A diferencia de la versión anterior en Node.js, **este backend no lee
archivos `.env`**: Dart lee las variables de entorno directamente del
sistema operativo. Revisa `.env.example` para el detalle, o usa:

**Linux / macOS (bash o zsh):**
```bash
export ADMIN_USERS="admin:maykel2026,juan:clave123,maria:clave456"
export PORT=8080
```

**Windows (PowerShell):**
```powershell
$env:ADMIN_USERS = "admin:maykel2026,juan:clave123,maria:clave456"
$env:PORT = "8080"
```

Si no defines `ADMIN_USERS`, se usa por defecto `admin:maykel2026`.
Si no defines `PORT`, se usa `8080`.

## Correr el servidor

```bash
dart run bin/server.dart
```

Verás:
```
Catálogo Maykel Repuestos (Dart) corriendo en http://0.0.0.0:8080
```

La primera vez que corre, crea automáticamente `catalogo_db.json` con las
130 categorías y 46 marcas reales del negocio (tomadas de
`categorias.json`/`marcas.json`) y 5 productos de ejemplo, para que el
catálogo no aparezca vacío mientras cargas el inventario real desde el
panel de Stock.

## Cómo se conecta con la app Flutter

Tienes dos formas de desplegar esto:

**Opción A — Un solo servidor (recomendada para producción):**
1. Compila la app Flutter: `cd ../app && flutter build web`
2. Esto genera `app/build/web/`.
3. Corre el backend normalmente (`dart run bin/server.dart`): detecta que
   existe `app/build/web` y sirve la app ahí mismo, en la misma URL y
   puerto que la API. No necesitas configurar CORS ni URLs separadas.

**Opción B — Backend y frontend separados (útil en desarrollo):**
1. Corre el backend: `dart run bin/server.dart` (por ejemplo, en
   `http://localhost:8080`).
2. Corre la app Flutter apuntando a esa URL:
   `flutter run -d chrome --dart-define=API_BASE=http://localhost:8080`
3. El backend ya incluye cabeceras CORS abiertas para que esto funcione
   sin configuración adicional.

## Estructura de datos

Toda la información vive en `catalogo_db.json` (se crea automáticamente):

```json
{
  "categorias": [...],
  "marcas": [...],
  "repuestos": [{ "id": 1, "nombre": "...", "categoria": "...", "marca": "...", "modelo": "...", "precio": 0, "stock": 0 }],
  "reservas": [...],
  "ventas": [...]
}
```

Puedes editar el stock/precio real de tus productos desde la pestaña
**Stock** del panel admin, una vez que hayas cargado tus productos reales
(agregándolos directamente en `catalogo_db.json` o ampliando el panel
admin a futuro con un formulario de alta de productos).


