import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/reminder.dart';
import '../services/cuidador_service.dart';
import 'cuidador_crear_recordatorio.dart';
import 'cuidador_reminder_detail_screen.dart';

class CuidadorRecordatoriosPacienteDetalleScreen extends StatefulWidget {
  final UserModel paciente;

  const CuidadorRecordatoriosPacienteDetalleScreen({
    Key? key,
    required this.paciente,
  }) : super(key: key);

  @override
  _CuidadorRecordatoriosPacienteDetalleScreenState createState() => _CuidadorRecordatoriosPacienteDetalleScreenState();
}

class _CuidadorRecordatoriosPacienteDetalleScreenState extends State<CuidadorRecordatoriosPacienteDetalleScreen> with TickerProviderStateMixin {
  final CuidadorService _cuidadorService = CuidadorService();
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Reminder> _todosLosRecordatorios = [];
  List<Reminder> _pendientes = [];
  List<Reminder> _completados = [];
  List<Reminder> _vencidos = [];
  Map<String, int> _estadisticas = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarRecordatorios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarRecordatorios() async {
    setState(() => _isLoading = true);
    
    try {
      final recordatorios = await _cuidadorService.getRecordatoriosPaciente(widget.paciente.userId!);
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      
      // Ajuste: para HOY ignoramos el flag isCompleted (usamos la nueva lógica por fecha)
      final pendientes = recordatorios.where((r) {
        final rd = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
        final esHoy = rd.isAtSameMomentAs(hoy);
        if (esHoy) {
          // Para hoy: mostrar como pendiente si la hora aún no pasa
          return r.dateTime.isAfter(ahora);
        }
        // Para otras fechas: mantener la lógica antigua temporalmente
        return !r.isCompleted && r.dateTime.isAfter(ahora);
      }).toList();
      
      final completados = recordatorios.where((r) => r.isCompleted).toList();
      
      final vencidos = recordatorios.where((r) {
        final dt = r.dateTime.toLocal();
        final ca = r.createdAt?.toLocal();
        final rd = DateTime(dt.year, dt.month, dt.day);
        final esHoy = rd.isAtSameMomentAs(hoy);
        if (esHoy) {
          // Para hoy: considerar vencido si la hora ya pasó, excepto si se creó después de la hora programada
          final createdAfterSchedule = ca != null && ca.isAfter(dt);
          return dt.isBefore(ahora) && !createdAfterSchedule;
        }
        return !r.isCompleted && dt.isBefore(ahora);
      }).toList();
      
      // Ordenar recordatorios
      pendientes.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      completados.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // Más recientes primero
      vencidos.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // Más recientes primero
      recordatorios.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      
      final estadisticas = {
        'total': recordatorios.length,
        'pendientes': pendientes.length,
        'completados': completados.length,
        'vencidos': vencidos.length,
        'adherencia': recordatorios.length > 0 ? ((completados.length / recordatorios.length) * 100).round() : 0,
      };
      
      setState(() {
        _todosLosRecordatorios = recordatorios;
        _pendientes = pendientes;
        _completados = completados;
        _vencidos = vencidos;
        _estadisticas = estadisticas;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando recordatorios: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los recordatorios'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 18,
              child: Text(
                widget.paciente.persona.nombres.isNotEmpty 
                  ? widget.paciente.persona.nombres[0].toUpperCase()
                  : 'P',
                style: TextStyle(
                  color: Color(0xFF1E3A5F),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recordatorios de',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    widget.paciente.persona.nombres,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarRecordatorios,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CuidadorCrearRecordatorioScreen(
                pacienteId: widget.paciente.userId!,
                paciente: widget.paciente,
              ),
            ),
          ).then((result) {
            if (result == true) {
              _cargarRecordatorios();
            }
          });
        },
        backgroundColor: Color(0xFF4A90E2),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Agregar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF4A90E2)),
          SizedBox(height: 16),
          Text(
            'Cargando recordatorios...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildEstadisticas(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRecordatoriosList(_todosLosRecordatorios, 'todos'),
              _buildRecordatoriosList(_pendientes, 'pendientes'),
              _buildRecordatoriosList(_vencidos, 'vencidos'),
              _buildRecordatoriosList(_completados, 'completados'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEstadisticas() {
    final adherencia = _estadisticas['adherencia'] ?? 0;
    Color adherenciaColor;
    if (adherencia >= 80) {
      adherenciaColor = Colors.green;
    } else if (adherencia >= 60) {
      adherenciaColor = Colors.orange;
    } else {
      adherenciaColor = Colors.red;
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF4A90E2), size: 20),
              SizedBox(width: 8),
              Text(
                'Estadísticas del Paciente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: adherenciaColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: adherenciaColor.withOpacity(0.3)),
                ),
                child: Text(
                  '${adherencia}% adherencia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: adherenciaColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total', _estadisticas['total'] ?? 0, Colors.blue, Icons.list_alt)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Pendientes', _estadisticas['pendientes'] ?? 0, Colors.orange, Icons.schedule)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Vencidos', _estadisticas['vencidos'] ?? 0, Colors.red, Icons.warning)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Completados', _estadisticas['completados'] ?? 0, Colors.green, Icons.check_circle)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Color(0xFF4A90E2),
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Color(0xFF4A90E2),
        indicatorWeight: 3,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        tabs: [
          Tab(text: 'Todos (${_estadisticas['total'] ?? 0})'),
          Tab(text: 'Pendientes (${_estadisticas['pendientes'] ?? 0})'),
          Tab(text: 'Vencidos (${_estadisticas['vencidos'] ?? 0})'),
          Tab(text: 'Completados (${_estadisticas['completados'] ?? 0})'),
        ],
      ),
    );
  }

  Widget _buildRecordatoriosList(List<Reminder> recordatorios, String tipo) {
    if (recordatorios.isEmpty) {
      return _buildEmptyState(tipo);
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: recordatorios.length,
      itemBuilder: (context, index) {
        final recordatorio = recordatorios[index];
        return _buildRecordatorioCard(recordatorio, tipo);
      },
    );
  }

  Widget _buildEmptyState(String tipo) {
    String mensaje;
    IconData icono;
    Color color;
    
    switch (tipo) {
      case 'pendientes':
        mensaje = 'No hay recordatorios pendientes';
        icono = Icons.schedule;
        color = Colors.orange;
        break;
      case 'vencidos':
        mensaje = 'No hay recordatorios vencidos';
        icono = Icons.warning;
        color = Colors.red;
        break;
      case 'completados':
        mensaje = 'No hay recordatorios completados';
        icono = Icons.check_circle;
        color = Colors.green;
        break;
      default:
        mensaje = 'No hay recordatorios';
        icono = Icons.event_note;
        color = Colors.grey;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 64,
              color: color.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              mensaje,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (tipo == 'todos')
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Usa el botón "+" para agregar el primer recordatorio',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordatorioCard(Reminder recordatorio, String tipo) {
    final ahora = DateTime.now();
    final dt = recordatorio.dateTime.toLocal();
    final ca = recordatorio.createdAt?.toLocal();
    final isHoy = dt.day == ahora.day && dt.month == ahora.month && dt.year == ahora.year;
    final createdAfterSchedule = isHoy && ca != null && ca.isAfter(dt);
    final isVencido = !recordatorio.isCompleted && dt.isBefore(ahora) && !createdAfterSchedule;
    final isPendiente = !recordatorio.isCompleted && recordatorio.dateTime.isAfter(ahora);

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey[300]!;
    Color iconColor = Colors.grey[600]!;
    
    if (recordatorio.isCompleted) {
      cardColor = Colors.green[50]!;
      borderColor = Colors.green[200]!;
      iconColor = Colors.green[600]!;
    } else if (isVencido) {
      cardColor = Colors.red[50]!;
      borderColor = Colors.red[200]!;
      iconColor = Colors.red[600]!;
    } else if (isHoy) {
      cardColor = Colors.blue[50]!;
      borderColor = Colors.blue[200]!;
      iconColor = Colors.blue[600]!;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CuidadorReminderDetailScreen(
                  reminder: recordatorio,
                ),
              ),
            ).then((_) {
              _cargarRecordatorios();
            });
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    recordatorio.type == 'medication' ? Icons.medication : Icons.directions_run,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recordatorio.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recordatorio.description.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            recordatorio.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(recordatorio.dateTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (recordatorio.frequency != 'Una vez')
                            Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  recordatorio.frequency,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Column(
                  children: [
                    if (recordatorio.isCompleted)
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.green[700], size: 16),
                      )
                    else if (isVencido)
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.warning, color: Colors.red[700], size: 16),
                      )
                    else if (isHoy)
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.today, color: Colors.blue[700], size: 16),
                      ),
                    SizedBox(height: 8),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
