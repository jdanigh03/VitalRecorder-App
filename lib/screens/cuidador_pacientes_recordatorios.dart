import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../models/reminder.dart';
import '../services/cuidador_service.dart';
import 'cuidador_recordatorios_paciente_detalle.dart';
import 'cuidador_crear_recordatorio.dart';

class CuidadorPacientesRecordatoriosScreen extends StatefulWidget {
  @override
  _CuidadorPacientesRecordatoriosScreenState createState() => _CuidadorPacientesRecordatoriosScreenState();
}

class _CuidadorPacientesRecordatoriosScreenState extends State<CuidadorPacientesRecordatoriosScreen> {
  final CuidadorService _cuidadorService = CuidadorService();
  
  bool _isLoading = true;
  List<UserModel> _pacientes = [];
  Map<String, List<Reminder>> _recordatoriosPorPaciente = {};
  Map<String, Map<String, int>> _estadisticasPorPaciente = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar pacientes asignados
      final pacientes = await _cuidadorService.getPacientesAsignados();
      
      // Cargar recordatorios para cada paciente
      Map<String, List<Reminder>> recordatoriosPorPaciente = {};
      Map<String, Map<String, int>> estadisticasPorPaciente = {};
      
      for (final paciente in pacientes) {
        final recordatorios = await _cuidadorService.getRecordatoriosPaciente(paciente.userId!);
        recordatoriosPorPaciente[paciente.userId!] = recordatorios;
        
        // Calcular estadísticas
        final total = recordatorios.length;
        final completados = recordatorios.where((r) => r.isCompleted).length;
        final pendientes = recordatorios.where((r) => !r.isCompleted && r.dateTime.isAfter(DateTime.now())).length;
        final vencidos = recordatorios.where((r) => !r.isCompleted && r.dateTime.isBefore(DateTime.now())).length;
        
        estadisticasPorPaciente[paciente.userId!] = {
          'total': total,
          'completados': completados,
          'pendientes': pendientes,
          'vencidos': vencidos,
          'adherencia': total > 0 ? ((completados / total) * 100).round() : 0,
        };
      }
      
      setState(() {
        _pacientes = pacientes;
        _recordatoriosPorPaciente = recordatoriosPorPaciente;
        _estadisticasPorPaciente = estadisticasPorPaciente;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los datos'),
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
            Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                radius: 18,
                child: Icon(Icons.people, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recordatorios',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Por Pacientes',
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
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildPacientesContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showPatientSelectionDialog();
        },
        backgroundColor: Color(0xFF4A90E2),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Crear Recordatorio',
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
            'Cargando pacientes y recordatorios...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacientesContent() {
    if (_pacientes.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildResumenGeneral(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _pacientes.length,
            itemBuilder: (context, index) {
              final paciente = _pacientes[index];
              final estadisticas = _estadisticasPorPaciente[paciente.userId!] ?? {};
              return _buildPacienteCard(paciente, estadisticas);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No tienes pacientes asignados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Una vez que aceptes invitaciones de pacientes, podrás ver y gestionar sus recordatorios aquí',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenGeneral() {
    final totalPacientes = _pacientes.length;
    final totalRecordatorios = _estadisticasPorPaciente.values
        .map((stats) => stats['total'] ?? 0)
        .fold(0, (a, b) => a + b);
    final totalVencidos = _estadisticasPorPaciente.values
        .map((stats) => stats['vencidos'] ?? 0)
        .fold(0, (a, b) => a + b);
    final totalPendientes = _estadisticasPorPaciente.values
        .map((stats) => stats['pendientes'] ?? 0)
        .fold(0, (a, b) => a + b);

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
              Icon(Icons.bar_chart, color: Color(0xFF4A90E2), size: 20),
              SizedBox(width: 8),
              Text(
                'Resumen General',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Pacientes', totalPacientes, Colors.blue, Icons.people)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Recordatorios', totalRecordatorios, Colors.green, Icons.schedule)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Pendientes', totalPendientes, Colors.orange, Icons.pending_actions)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Vencidos', totalVencidos, Colors.red, Icons.warning)),
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
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacienteCard(UserModel paciente, Map<String, int> estadisticas) {
    final total = estadisticas['total'] ?? 0;
    final pendientes = estadisticas['pendientes'] ?? 0;
    final vencidos = estadisticas['vencidos'] ?? 0;
    final adherencia = estadisticas['adherencia'] ?? 0;

    Color adherenciaColor;
    if (adherencia >= 80) {
      adherenciaColor = Colors.green;
    } else if (adherencia >= 60) {
      adherenciaColor = Colors.orange;
    } else {
      adherenciaColor = Colors.red;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CuidadorRecordatoriosPacienteDetalleScreen(
                  paciente: paciente,
                ),
              ),
            ).then((_) {
              _cargarDatos(); // Recargar datos al regresar
            });
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFF4A90E2),
                      radius: 24,
                      child: Text(
                        paciente.persona.nombres.isNotEmpty 
                          ? paciente.persona.nombres[0].toUpperCase()
                          : 'P',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paciente.persona.nombres,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          Text(
                            paciente.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Expanded(
                      child: _buildMiniStat('Total', total, Colors.grey[700]!, Icons.list_alt),
                    ),
                    Expanded(
                      child: _buildMiniStat('Pendientes', pendientes, Colors.orange, Icons.schedule),
                    ),
                    Expanded(
                      child: _buildMiniStat('Vencidos', vencidos, Colors.red, Icons.warning),
                    ),
                  ],
                ),
                if (vencidos > 0 || pendientes > 0)
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: vencidos > 0 ? Colors.red[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: vencidos > 0 ? Colors.red[200]! : Colors.orange[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          vencidos > 0 ? Icons.warning : Icons.info,
                          color: vencidos > 0 ? Colors.red[600] : Colors.orange[600],
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vencidos > 0 
                              ? 'Tiene $vencidos recordatorio${vencidos > 1 ? 's' : ''} vencido${vencidos > 1 ? 's' : ''}'
                              : 'Tiene $pendientes recordatorio${pendientes > 1 ? 's' : ''} pendiente${pendientes > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: vencidos > 0 ? Colors.red[700] : Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String title, int value, Color color, IconData icon) {
    return Column(
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
            color: color,
          ),
        ),
      ],
    );
  }

  void _showPatientSelectionDialog() {
    if (_pacientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No tienes pacientes asignados para crear recordatorios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Seleccionar Paciente',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A5F),
          ),
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _pacientes.length,
            separatorBuilder: (context, index) => Divider(),
            itemBuilder: (context, index) {
              final paciente = _pacientes[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF4A90E2),
                  child: Text(
                    paciente.persona.nombres.isNotEmpty
                        ? paciente.persona.nombres[0].toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  paciente.persona.nombres,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  paciente.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CuidadorCrearRecordatorioScreen(
                        pacienteId: paciente.userId!,
                        paciente: paciente,
                      ),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _cargarDatos();
                    }
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
