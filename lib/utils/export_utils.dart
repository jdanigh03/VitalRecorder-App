import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/reminder_new.dart';
import '../models/user.dart';

class ExportUtils {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _timestampFormat = DateFormat('yyyyMMdd_HHmmss');

  /// Genera un reporte PDF con estadísticas de adherencia
  static Future<void> generatePDF({
    required List<ReminderNew> reminders,
    required DateTime startDate,
    required DateTime endDate,
    String? patientName,
    Map<String, dynamic>? stats,
  }) async {
    try {
      final pdf = pw.Document();

      // Calcular estadísticas
      // Calcular estadísticas
      final rawStats = stats ?? _calculateStatistics(reminders);
      final finalStats = {
        'total': rawStats['total'] ?? rawStats['totalRecordatorios'] ?? 0,
        'completed': rawStats['completed'] ?? rawStats['completados'] ?? 0,
        'missed': rawStats['missed'] ?? rawStats['vencidos'] ?? 0,
        'pending': rawStats['pending'] ?? rawStats['pendientes'] ?? 0,
        'adherenceRate': rawStats['adherenceRate'] ?? rawStats['adherenciaGeneral'] ?? 0,
      };
      
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
              _buildStatisticsSection(finalStats),
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
    required List<ReminderNew> reminders,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Ordenar recordatorios por fecha
      final sortedReminders = List<ReminderNew>.from(reminders)
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      // Crear datos CSV
      List<List<dynamic>> csvData = [
        ['Fecha Inicio', 'Fecha Fin', 'Medicamento/Actividad', 'Descripción', 'Tipo', 'Intervalo', 'Horarios']
      ];

      for (final reminder in sortedReminders) {
        csvData.add([
          _dateFormat.format(reminder.startDate),
          _dateFormat.format(reminder.endDate),
          reminder.title,
          reminder.description,
          _getTypeText(reminder.type),
          reminder.intervalDisplayText,
          reminder.dailyScheduleTimes.map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}').join(', '),
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
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'REPORTE DE CUMPLIMIENTO',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700),
                  borderRadius: pw.BorderRadius.circular(20),
                ),
                child: pw.Text(
                  'VitalRecorder',
                  style: pw.TextStyle(
                    color: PdfColors.black,
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
            'RESUMEN DE CUMPLIMIENTO',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard('Tasa de Cumplimiento', '${stats['adherenceRate']}%', PdfColors.grey700),
              _buildStatCard('Total Recordatorios', '${stats['total']}', PdfColors.grey700),
              _buildStatCard('Completados', '${stats['completed']}', PdfColors.grey700),
              _buildStatCard('Omitidos', '${stats['missed']}', PdfColors.grey700),
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
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
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
  static pw.Widget _buildRemindersTable(List<ReminderNew> reminders) {
    // Ordenar por fecha
    final sortedReminders = List<ReminderNew>.from(reminders)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'DETALLE DE RECORDATORIOS',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
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
                _buildTableCell(_dateFormat.format(reminder.startDate)),
                _buildTableCell(reminder.dateRangeText),
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
            '- COMPLETADO: Recordatorio marcado como tomado/realizado',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '- OMITIDO: Recordatorio no completado después de la fecha/hora programada',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '- PENDIENTE: Recordatorio programado para fecha/hora futura',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '- PAUSADO: Recordatorio temporalmente suspendido (no cuenta en estadísticas)',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Calcula estadísticas de adherencia usando la lógica real de vencimientos
  static Map<String, dynamic> _calculateStatistics(List<ReminderNew> reminders) {
    final now = DateTime.now();
    final total = reminders.length;
    final active = reminders.where((r) => r.isActive).length;
    final completed = reminders.where((r) => !r.isActive && r.endDate.isBefore(now)).length;
    final missed = 0; // Requiere consultar confirmaciones
    final pending = active;
    
    // Calcular adherencia simplificada
    final adherenceRate = total > 0 ? ((completed / total) * 100).round() : 0;

    return {
      'total': total,
      'completed': completed,
      'missed': missed,
      'pending': pending,
      'adherenceRate': adherenceRate,
    };
  }

  /// Convierte el estado del recordatorio a texto usando lógica real
  static String _getStatusText(ReminderNew reminder) {
    final now = DateTime.now();
    
    // Verificar si está pausado primero
    if (reminder.isPaused) return 'PAUSADO';
    if (!reminder.isActive) return 'FINALIZADO';
    if (reminder.endDate.isBefore(now)) return 'VENCIDO';
    if (reminder.startDate.isAfter(now)) return 'PROGRAMADO';
    
    return 'ACTIVO';
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

  // ========== MÉTODOS ESPECÍFICOS PARA CUIDADOR ==========

  /// Genera reporte PDF completo para cuidador con todos los pacientes
  static Future<void> generateCuidadorCompletePDF({
    required List<UserModel> pacientes,
    required List<ReminderNew> allReminders,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> stats,
    Map<String, dynamic>? options,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Encabezado del cuidador
              _buildCuidadorHeader(startDate, endDate, pacientes.length, options),
              pw.SizedBox(height: 20),
              
              // Resumen general
              _buildCuidadorGeneralStats(stats, allReminders),
              pw.SizedBox(height: 20),
              
              // Gráficos (si están habilitados)
              if (options?['includeGraphs'] == true) ...[
                _buildGraphsPlaceholder(),
                pw.SizedBox(height: 20),
              ],
              
              // Análisis por paciente (si detalles están habilitados)
              if (options?['includeDetails'] == true)
                _buildCuidadorPatientAnalysis(pacientes, allReminders),
            ];
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
              child: pw.Text(
                'VitalRecorder - Reporte Cuidador - Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            );
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final fileName = 'reporte_cuidador_completo_${_timestampFormat.format(DateTime.now())}.pdf';
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Reporte Completo del Cuidador');
      
    } catch (e) {
      throw Exception('Error generando reporte PDF del cuidador: $e');
    }
  }

  /// Genera reporte PDF específico de un paciente para el cuidador
  static Future<void> generateCuidadorPatientPDF({
    required UserModel paciente,
    required List<ReminderNew> patientReminders,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> stats,
  }) async {
    try {
      final pdf = pw.Document();
      
      // Normalizar estadísticas para asegurar compatibilidad de claves
      final normalizedStats = {
        'total': stats['total'] ?? stats['totalRecordatorios'] ?? 0,
        'completed': stats['completed'] ?? stats['completados'] ?? 0,
        'missed': stats['missed'] ?? stats['vencidos'] ?? 0,
        'pending': stats['pending'] ?? stats['pendientes'] ?? 0,
        'adherenceRate': stats['adherenceRate'] ?? stats['adherenciaGeneral'] ?? 0,
      };

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Encabezado específico del paciente
              _buildPatientHeader(paciente, startDate, endDate),
              pw.SizedBox(height: 20),
              
              // Estadísticas del paciente
              _buildStatisticsSection(normalizedStats),
              pw.SizedBox(height: 20),
              
              // Tabla de recordatorios del paciente
              _buildRemindersTable(patientReminders),
              pw.SizedBox(height: 20),
              
              // Análisis de adherencia específico
              _buildPatientAdherenceAnalysis(normalizedStats),
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
                'VitalRecorder - Reporte Paciente - Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            );
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final patientName = paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto : 'Paciente';
      final fileName = 'reporte_${patientName.replaceAll(' ', '_')}_${_timestampFormat.format(DateTime.now())}.pdf';
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de $patientName');
      
    } catch (e) {
      throw Exception('Error generando reporte del paciente: $e');
    }
  }

  /// Genera archivo Excel/CSV consolidado para el cuidador
  static Future<void> generateCuidadorExcel({
    required List<UserModel> pacientes,
    required List<ReminderNew> allReminders,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> patientStats,
    Map<String, dynamic>? options,
  }) async {
    try {
      final sortedReminders = List<ReminderNew>.from(allReminders)
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      // Crear datos CSV con información del paciente
      List<List<dynamic>> csvData = [];
      
      // Encabezado básico
      if (options?['includeDetails'] == true) {
        csvData.add(['Paciente', 'Email', 'Fecha', 'Hora', 'Medicamento/Actividad', 'Descripción', 'Tipo', 'Estado', 'Frecuencia', 'Creado']);
      } else {
        csvData.add(['Paciente', 'Fecha', 'Hora', 'Medicamento/Actividad', 'Estado']);
      }

      for (final reminder in sortedReminders) {
        // Buscar el paciente correspondiente al recordatorio
        final paciente = pacientes.firstWhere(
          (p) => p.id == reminder.userId,
          orElse: () => UserModel(
            id: '',
            email: 'Desconocido',
            persona: UserPersona(
              nombres: 'Paciente no',
              apellidos: 'encontrado',
            ),
            settings: UserSettings(telefono: ''),
            createdAt: DateTime.now(),
          ),
        );

        if (options?['includeDetails'] == true) {
          csvData.add([
            paciente.persona.nombres + ' ' + paciente.persona.apellidos,
            paciente.email,
            _dateFormat.format(reminder.startDate),
            _dateFormat.format(reminder.endDate),
            reminder.title,
            reminder.description,
            _getTypeText(reminder.type),
            _getStatusText(reminder),
            reminder.intervalDisplayText,
            'N/A',
          ]);
        } else {
          csvData.add([
            paciente.persona.nombres + ' ' + paciente.persona.apellidos,
            _dateFormat.format(reminder.startDate),
            _dateFormat.format(reminder.endDate),
            reminder.title,
            _getStatusText(reminder),
          ]);
        }
      }

      // Agregar hoja de estadísticas por paciente
      csvData.add([]); // Línea vacía
      csvData.add(['=== ESTADÍSTICAS POR PACIENTE ===']);
      csvData.add(['Paciente', 'Email', 'Total', 'Completados', 'Omitidos', 'Pendientes', 'Adherencia (%)']);

      for (final paciente in pacientes) {
        // Buscar stats del paciente
        final patientStat = patientStats.firstWhere(
          (s) => (s['patient'] as UserModel).userId == paciente.userId,
          orElse: () => {
            'totalRecordatorios': 0,
            'completados': 0,
            'vencidos': 0,
            'pendientes': 0,
            'adherencia': 0,
          },
        );
        
        csvData.add([
          paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto : 'Sin nombre',
          paciente.email,
          patientStat['totalRecordatorios'],
          patientStat['completados'],
          patientStat['vencidos'],
          patientStat['pendientes'],
          patientStat['adherencia'],
        ]);
      }

      // Convertir a CSV
      String csvString = const ListToCsvConverter().convert(csvData);

      // Guardar archivo
      final output = await getApplicationDocumentsDirectory();
      final fileName = 'reporte_cuidador_${_timestampFormat.format(DateTime.now())}.csv';
      final file = File("${output.path}/$fileName");
      await file.writeAsString(csvString, encoding: utf8);

      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Cuidador - Datos Excel');
      
    } catch (e) {
      throw Exception('Error generando Excel del cuidador: $e');
    }
  }

  /// Genera resumen ejecutivo para el cuidador
  static Future<void> generateCuidadorExecutiveSummary({
    required List<UserModel> pacientes,
    required Map<String, dynamic> stats,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado ejecutivo
                _buildExecutiveHeader(startDate, endDate),
                pw.SizedBox(height: 30),
                
                // Métricas clave
                _buildExecutiveMetrics(stats, pacientes.length),
                pw.SizedBox(height: 30),
                
                // Alertas y recomendaciones
                _buildExecutiveAlerts(stats),
                pw.SizedBox(height: 30),
                
                // Pacientes destacados
                _buildTopPatients(pacientes),
              ],
            );
          },
        ),
      );

      final output = await getApplicationDocumentsDirectory();
      final fileName = 'resumen_ejecutivo_${_timestampFormat.format(DateTime.now())}.pdf';
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Resumen Ejecutivo del Cuidador');
      
    } catch (e) {
      throw Exception('Error generando resumen ejecutivo: $e');
    }
  }

  // ========== MÉTODOS DE CONSTRUCCIÓN ESPECÍFICOS PARA CUIDADOR ==========

  static pw.Widget _buildCuidadorHeader(DateTime startDate, DateTime endDate, int totalPatients, [Map<String, dynamic>? options]) {
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
                'REPORTE COMPLETO DEL CUIDADOR',
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
            'Pacientes bajo cuidado: $totalPatients',
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
          if (options != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Opciones: ${options['includeGraphs'] == true ? "Gráficos " : ""}${options['includeDetails'] == true ? "Detalles " : ""}${options['selectedPatient'] != null ? "Paciente específico " : ""}${options['selectedType'] != null ? "Tipo: ${options['selectedType']}" : ""}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildPatientHeader(UserModel paciente, DateTime startDate, DateTime endDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'REPORTE INDIVIDUAL DE PACIENTE',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green800,
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
            'Paciente: ${paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto : 'Sin nombre registrado'}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Email: ${paciente.email}',
            style: const pw.TextStyle(fontSize: 14),
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

  static pw.Widget _buildCuidadorGeneralStats(Map<String, dynamic> stats, List<ReminderNew> allReminders) {
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
            'ESTADÍSTICAS GENERALES',
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
              _buildStatCard('Pacientes', '${stats['totalPacientes'] ?? 0}', PdfColors.blue),
              _buildStatCard('Adherencia Promedio', '${stats['adherenciaGeneral'] ?? 0}%', PdfColors.green),
              _buildStatCard('Recordatorios Activos', '${stats['recordatoriosActivos'] ?? 0}', PdfColors.orange),
              _buildStatCard('Alertas Críticas', '${stats['alertasHoy'] ?? 0}', PdfColors.red),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCuidadorPatientAnalysis(List<UserModel> pacientes, List<ReminderNew> allReminders) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ANÁLISIS POR PACIENTE',
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
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FixedColumnWidth(80),
            3: const pw.FixedColumnWidth(80),
            4: const pw.FixedColumnWidth(80),
            5: const pw.FixedColumnWidth(80),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Paciente', isHeader: true),
                _buildTableCell('Email', isHeader: true),
                _buildTableCell('Total', isHeader: true),
                _buildTableCell('Completados', isHeader: true),
                _buildTableCell('Omitidos', isHeader: true),
                _buildTableCell('Adherencia', isHeader: true),
              ],
            ),
            // Data rows
            ...pacientes.take(10).map((paciente) { // Limitar a 10 para que quepa en la página
              final patientReminders = allReminders.where((r) => r.userId == paciente.id).toList();
              final stats = _calculateStatistics(patientReminders);
              return pw.TableRow(
                children: [
                  _buildTableCell(paciente.nombreCompleto.isNotEmpty ? paciente.nombreCompleto : 'Sin nombre'),
                  _buildTableCell(paciente.email),
                  _buildTableCell('${stats['total']}'),
                  _buildTableCell('${stats['completed']}'),
                  _buildTableCell('${stats['missed']}'),
                  _buildTableCell('${stats['adherenceRate']}%'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Método auxiliar para construir las recomendaciones de adherencia
  static List<pw.Widget> _getAdherenceRecommendations(int adherenceRate) {
    if (adherenceRate < 60) {
      return [
        pw.Text(
          'RECOMENDACIONES:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '- Incrementar recordatorios y seguimiento',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          '- Considerar ajustar horarios de medicación',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          '- Realizar seguimiento médico más frecuente',
          style: const pw.TextStyle(fontSize: 11),
        ),
      ];
    } else if (adherenceRate < 80) {
      return [
        pw.Text(
          'RECOMENDACIONES:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '- Mantener seguimiento regular',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Text(
          '- Reforzar educación sobre la importancia del tratamiento',
          style: const pw.TextStyle(fontSize: 11),
        ),
      ];
    } else {
      return [
        pw.Text(
          'FELICITACIONES:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '- El paciente mantiene una excelente adherencia al tratamiento',
          style: const pw.TextStyle(fontSize: 11),
        ),
      ];
    }
  }

  /// Widget placeholder para gráficos en PDF
  static pw.Widget _buildGraphsPlaceholder() {
    return pw.Container(
      height: 150,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'GRÁFICOS Y VISUALIZACIONES',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildGraphPlaceholder('Tendencia\nde Adherencia', PdfColors.green),
              _buildGraphPlaceholder('Distribución\npor Tipos', PdfColors.blue),
              _buildGraphPlaceholder('Ranking de\nPacientes', PdfColors.orange),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Los gráficos interactivos están disponibles en la aplicación',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildGraphPlaceholder(String title, PdfColor color) {
    return pw.Container(
      width: 120,
      height: 80,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 30,
            height: 30,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                '•',
                style: pw.TextStyle(
                  fontSize: 16,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 8, color: color),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPatientAdherenceAnalysis(Map<String, dynamic> stats) {
    final adherenceRate = stats['adherenceRate'] as int;
    PdfColor adherenceColor;
    String adherenceText;
    
    if (adherenceRate >= 80) {
      adherenceColor = PdfColors.green;
      adherenceText = 'EXCELENTE';
    } else if (adherenceRate >= 60) {
      adherenceColor = PdfColors.orange;
      adherenceText = 'REGULAR';
    } else {
      adherenceColor = PdfColors.red;
      adherenceText = 'NECESITA ATENCIÓN';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: adherenceColor.shade(0.1),
        border: pw.Border.all(color: adherenceColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ANÁLISIS DE ADHERENCIA',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: adherenceColor,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Estado: $adherenceText ($adherenceRate%)',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: adherenceColor,
            ),
          ),
          pw.SizedBox(height: 8),
          ..._getAdherenceRecommendations(adherenceRate),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveHeader(DateTime startDate, DateTime endDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'RESUMEN EJECUTIVO',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo800,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.indigo800,
                  borderRadius: pw.BorderRadius.circular(25),
                ),
                child: pw.Text(
                  'VitalRecorder',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Período de análisis: ${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
            style: const pw.TextStyle(fontSize: 16),
          ),
          pw.Text(
            'Generado: ${_dateFormat.format(DateTime.now())} ${_timeFormat.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveMetrics(Map<String, dynamic> stats, int totalPatients) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 2),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MÉTRICAS CLAVE',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo800,
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildExecutiveStatCard(
                'PACIENTES\nACTIVOS',
                '$totalPatients',
                PdfColors.blue,
              ),
              _buildExecutiveStatCard(
                'ADHERENCIA\nPROMEDIO',
                '${stats['adherenciaGeneral'] ?? 0}%',
                PdfColors.green,
              ),
              _buildExecutiveStatCard(
                'ALERTAS\nCRÍTICAS',
                '${stats['alertasHoy'] ?? 0}',
                PdfColors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildExecutiveStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 36,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Método auxiliar para construir las alertas ejecutivas
  static List<pw.Widget> _getExecutiveAlerts(int adherencia, int alertas) {
    List<pw.Widget> widgets = [];
    
    widgets.add(pw.Text(
      'ALERTAS Y RECOMENDACIONES',
      style: pw.TextStyle(
        fontSize: 18,
        fontWeight: pw.FontWeight.bold,
        color: alertas > 5 ? PdfColors.red800 : PdfColors.green800,
      ),
    ));
    
    widgets.add(pw.SizedBox(height: 10));
    
    if (alertas > 5) {
      widgets.add(pw.Text(
        '⚠ ATENCIÓN REQUERIDA:',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.red,
        ),
      ));
      widgets.add(pw.Text(
        '• Hay $alertas alertas críticas que requieren intervención inmediata',
        style: const pw.TextStyle(fontSize: 12),
      ));
    }
    
    if (adherencia < 70) {
      widgets.add(pw.Text(
        '• La adherencia promedio ($adherencia%) está por debajo del objetivo (70%)',
        style: const pw.TextStyle(fontSize: 12),
      ));
      widgets.add(pw.Text(
        '• Se recomienda reforzar el seguimiento con los pacientes',
        style: const pw.TextStyle(fontSize: 12),
      ));
    } else {
      widgets.add(pw.Text(
        '✓ ESTADO SATISFACTORIO:',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green,
        ),
      ));
      widgets.add(pw.Text(
        '• La adherencia promedio ($adherencia%) está dentro del rango objetivo',
        style: const pw.TextStyle(fontSize: 12),
      ));
    }
    
    return widgets;
  }

  static pw.Widget _buildExecutiveAlerts(Map<String, dynamic> stats) {
    final adherencia = stats['adherenciaGeneral'] ?? 0;
    final alertas = stats['alertasHoy'] ?? 0;
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: alertas > 5 ? PdfColors.red50 : PdfColors.green50,
        border: pw.Border.all(
          color: alertas > 5 ? PdfColors.red : PdfColors.green,
          width: 2,
        ),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: _getExecutiveAlerts(adherencia, alertas),
      ),
    );
  }

  /// Método auxiliar para construir la lista de pacientes
  static List<pw.Widget> _getTopPatientsWidgets(List<UserModel> pacientes) {
    List<pw.Widget> widgets = [
      pw.Text(
        'RESUMEN DE PACIENTES',
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.indigo800,
        ),
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        'Total de pacientes bajo cuidado: ${pacientes.length}',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ];
    
    if (pacientes.length > 5) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        'Los primeros 5 pacientes:',
        style: const pw.TextStyle(fontSize: 12),
      ));
      
      // Agregar los primeros 5 pacientes
      for (final p in pacientes.take(5)) {
        widgets.add(pw.Text(
          '• ${p.nombreCompleto.isNotEmpty ? p.nombreCompleto : 'Sin nombre'} (${p.email})',
          style: const pw.TextStyle(fontSize: 11),
        ));
      }
      
      widgets.add(pw.Text(
        '... y ${pacientes.length - 5} pacientes más',
        style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
      ));
    } else {
      widgets.add(pw.SizedBox(height: 8));
      
      // Agregar todos los pacientes
      for (final p in pacientes) {
        widgets.add(pw.Text(
          '• ${p.nombreCompleto.isNotEmpty ? p.nombreCompleto : 'Sin nombre'} (${p.email})',
          style: const pw.TextStyle(fontSize: 11),
        ));
      }
    }
    
    return widgets;
  }

  static pw.Widget _buildTopPatients(List<UserModel> pacientes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: _getTopPatientsWidgets(pacientes),
      ),
    );
  }
}
