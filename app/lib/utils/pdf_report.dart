import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Genera y abre el diálogo de impresión/descarga de un reporte PDF simple:
/// un título y una tabla de columnas/filas. Se usa para "Descargar ventas
/// en PDF" y "Descargar reservas en PDF" en el panel admin.
Future<void> generarReportePdf({
  required String titulo,
  required List<String> columnas,
  required List<List<String>> filas,
}) async {
  final doc = pw.Document();
  final fechaGeneracion = DateTime.now();
  final fechaStr = '${fechaGeneracion.day.toString().padLeft(2, '0')}/'
      '${fechaGeneracion.month.toString().padLeft(2, '0')}/'
      '${fechaGeneracion.year} '
      '${fechaGeneracion.hour.toString().padLeft(2, '0')}:'
      '${fechaGeneracion.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(
          '$titulo — Maykel Repuestos',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generado el $fechaStr',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        pw.Table.fromTextArray(
          headers: columnas,
          data: filas.isEmpty ? [List.filled(columnas.length, 'Sin registros')] : filas,
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey900),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellHeight: 24,
          cellAlignment: pw.Alignment.centerLeft,
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          ),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => doc.save(),
    name: '$titulo - Maykel Repuestos.pdf',
  );
}
