/// Formatea un monto como pesos chilenos (ej. 24990 -> "$24.990"),
/// sin depender de datos de configuración regional de `intl` (que
/// requeriría inicialización adicional y no vale la pena para un solo
/// formato de moneda).
String formatCLP(num valor) {
  final entero = valor.round();
  final negativo = entero < 0;
  final digitos = entero.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  return '${negativo ? '-' : ''}\$$buffer';
}
