import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/reminder.dart';

class ExportUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _timestampFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Genera un reporte PDF con estadísticas de adherencia
  static Future<void> generatePDF({
    required List<Reminder> reminders,
    required DateTime startDate,
    required DateTime endDate,
    String? patientName,
  }) async {
    try {
      final pdf = pw.Document();

      // Calcular estadísticas
      final stats = _calculateStatistics(reminders);
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Encabezado
              _buildHeader(patientName ?? 'Paciente', startDate, endDate),
              pw.SizedBox(height: 20),
              
              // Resumen de adherencia
              _buildStatisticsSection(stats),
              pw.SizedBox(height: 20),
              
              // Tabla de recordatorios
              _buildRemindersTable(reminders),
              pw.SizedBox(height: 20),
              
              // Notas explicativas
              _buildNotesSection(),
            ];
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
              child: pw.Text(
                'VitalRecorder App - Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            );
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final fileName = 'reporte_adherencia_${_timestampFormat.format(DateTime.now())}.pdf';
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Adherencia');
      
    } catch (e) {
      throw Exception('Error generando PDF: $e');
    }
  }

  /// Genera archivo CSV con los datos de recordatorios
  static Future<void> generateCSV({
    required List<Reminder> reminders,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Ordenar recordatorios por fecha
      final sortedReminders = List<Reminder>.from(reminders)
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Crear datos CSV
      List<List<dynamic>> csvData = [
        ['Fecha', 'Hora', 'Medicamento/Actividad', 'Descripción', 'Tipo', 'Estado', 'Frecuencia']
      ];

      for (final reminder in sortedReminders) {
        csvData.add([
          _dateFormat.format(reminder.dateTime),
          _timeFormat.format(reminder.dateTime),
          reminder.title,
          reminder.description,
          _getTypeText(reminder.type),
          _getStatusText(reminder),
          reminder.frequency,
        ]);
      }

      // Convertir a CSV
      String csvString = const ListToCsvConverter().convert(csvData);

      // Guardar archivo
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'recordatorios_${_timestampFormat.format(DateTime.now())}.csv';
      final file = File("${output.path}/$fileName");
      await file.writeAsString(csvString, encoding: utf8);

      await Share.shareXFiles([XFile(file.path)], text: 'Datos de Recordatorios');
      
    } catch (e) {
      throw Exception('Error generando CSV: $e');
    }
  }

  /// Construye el encabezado del PDF
  static pw.Widget _buildHeader(String patientName, DateTime startDate, DateTime endDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'REPORTE DE ADHERENCIA',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  'VitalRecorder',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Paciente: $patientName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Período: ${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
            style: const pw.TextStyle(fontSize: 14),
          ),
          pw.Text(
            'Fecha de generación: ${_dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Construye la sección de estadísticas
  static pw.Widget _buildStatisticsSection(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESUMEN DE ADHERENCIA',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Tasa de Adherencia', '${stats['adherenceRate']}%', PdfColors.green),
              _buildStatCard('Total Recordatorios', '${stats['total']}', PdfColors.blue),
              _buildStatCard('Completados', '${stats['completed']}', PdfColors.green),
              _buildStatCard('Omitidos', '${stats['missed']}', PdfColors.red),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye una tarjeta de estadística
  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Construye la tabla de recordatorios
  static pw.Widget _buildRemindersTable(List<Reminder> reminders) {
    // Ordenar por fecha
    final sortedReminders = List<Reminder>.from(reminders)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETALLE DE RECORDATORIOS',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FixedColumnWidth(80),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FixedColumnWidth(80),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Fecha', isHeader: true),
                _buildTableCell('Hora', isHeader: true),
                _buildTableCell('Medicamento', isHeader: true),
                _buildTableCell('Descripción', isHeader: true),
                _buildTableCell('Estado', isHeader: true),
              ],
            ),
            // Data rows
            ...sortedReminders.map((reminder) => pw.TableRow(
              children: [
                _buildTableCell(_dateFormat.format(reminder.dateTime)),
                _buildTableCell(_timeFormat.format(reminder.dateTime)),
                _buildTableCell(reminder.title),
                _buildTableCell(reminder.description),
                _buildTableCell(_getStatusText(reminder)),
              ],
            )),
          ],
        ),
      ],
    );
  }

  /// Construye una celda de tabla
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Construye la sección de notas explicativas
  static pw.Widget _buildNotesSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTAS:',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '• COMPLETADO: Recordatorio marcado como tomado/realizado',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '• OMITIDO: Recordatorio no completado después de la fecha/hora programada',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '• PENDIENTE: Recordatorio programado para fecha/hora futura',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Calcula estadísticas de adherencia
  static Map<String, dynamic> _calculateStatistics(List<Reminder> reminders) {
    final total = reminders.length;
    final completed = reminders.where((r) => r.isCompleted).length;
    final missed = reminders.where((r) => !r.isCompleted && r.dateTime.isBefore(DateTime.now())).length;
    final pending = total - completed - missed;
    
    final adherenceRate = total > 0 ? ((completed / (completed + missed)) * 100).round() : 0;

    return {
      'total': total,
      'completed': completed,
      'missed': missed,
      'pending': pending,
      'adherenceRate': adherenceRate,
    };
  }

  /// Convierte el estado del recordatorio a texto
  static String _getStatusText(Reminder reminder) {
    if (reminder.isCompleted) {
      return 'COMPLETADO';
    } else if (reminder.dateTime.isBefore(DateTime.now())) {
      return 'OMITIDO';
    } else {
      return 'PENDIENTE';
    }
  }

  /// Convierte el tipo del recordatorio a texto
  static String _getTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'medicación':
      case 'medication':
        return 'Medicación';
      case 'tarea':
      case 'activity':
        return 'Actividad';
      case 'cita':
      case 'appointment':
        return 'Cita Médica';
      default:
        // Si viene un tipo que no reconocemos, lo capitalizamos
        return type.isNotEmpty 
            ? '${type[0].toUpperCase()}${type.substring(1).toLowerCase()}'
            : 'Recordatorio';
    }
  }
}
