import 'package:flutter/material.dart';

/// URL base de la API. Vacío = mismo origen (cuando el backend Dart sirve
/// también el build web de Flutter). Para desarrollo separado, correr con:
///   flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
const String kApiBase = String.fromEnvironment('API_BASE', defaultValue: '');

/// Valores originales de contacto del negocio. Ya NO se usan en el sitio ni
/// en el panel admin: esos datos ahora son editables desde Configuración y
/// se guardan en el backend (ver ContenidoSitio en models.dart). Esta clase
/// queda solo como referencia histórica de los valores por defecto.
class ContactoConfig {
  static const String whatsappNumber = '569';
  static const String contactEmail = '@gmail.com';
  static const String direccion =
      'Vargas 2228-A, Calama, Región de Antofagasta';
  static const String mapsUrl =
      'https://www.google.com/maps/place/Maykel+Repuestos/@-22.4608953,-68.9286172,21z/data=!4m6!3m5!1s0x4ab51954d66992f7:0x3daf1bf514abec72!8m2!3d-22.4607923!4d-68.9285291';
  static const String horario =
      'Lunes a viernes, 9:30 – 19:00\nSábado, 9:30 – 14:00';
}

/// Paleta de colores del diseño original (industrial, rojo/carbón/amarillo).
class AppColors {
  static const Color red = Color(0xFFD91E2B);
  static const Color redDark = Color(0xFF9E1119);
  static const Color char = Color(0xFF1A1A1C);
  static const Color char2 = Color(0xFF242427);
  static const Color steel = Color(0xFF767B84);
  static const Color paper = Color(0xFFF2EFE9);
  static const Color paper2 = Color(0xFFE7E2D8);
  static const Color yellow = Color(0xFFF2B705);
  static const Color ok = Color(0xFF2E7D46);
  static const Color warn = Color(0xFFB8860B);
  static const Color bad = Color(0xFFB0201F);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.red,
      primary: AppColors.red,
      secondary: AppColors.yellow,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.paper,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: AppColors.paper2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}
