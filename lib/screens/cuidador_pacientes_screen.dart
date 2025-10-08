import 'package:flutter/material.dart';
import '../services/cuidador_service.dart';
import '../services/invitacion_service.dart';
import '../models/user.dart';
import 'invitaciones_cuidador.dart';
import 'cuidador_recordatorios_paciente_detalle.dart';
import '../models/invitacion_cuidador.dart';
import '../widgets/dashboard_widgets.dart';

class CuidadorPacientesScreen extends StatefulWidget {
  @override
  _CuidadorPacientesScreenState createState() => _CuidadorPacientesScreenState();
}

class _CuidadorPacientesScreenState extends State<CuidadorPacientesScreen> {
  final CuidadorService _cuidadorService = CuidadorService();
  final InvitacionService _invitacionService = InvitacionService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isLoadingInvitations = true;
  List<UserModel> _pacientes = [];
  List<InvitacionCuidador> _invitacionesPendientes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _loadInvitations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final pacientes = await _cuidadorService.getPacientes();
      setState(() {
        _pacientes = pacientes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando pacientes: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando pacientes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadInvitations() async {
    try {
      final invitaciones = await _invitacionService.getInvitacionesRecibidas();
      setState(() {
        _invitacionesPendientes = invitaciones.where((inv) => inv.esPendiente).toList();
        _isLoadingInvitations = false;
      });
    } catch (e) {
      print('Error cargando invitaciones: $e');
      setState(() => _isLoadingInvitations = false);
    }
  }

  List<UserModel> get _filteredPatients {
    if (_searchQuery.isEmpty) return _pacientes;
    
    return _pacientes.where((patient) {
      final name = patient.nombreCompleto.toLowerCase();
      final email = patient.email.toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return name.contains(query) || email.contains(query);
    }).toList();
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
                    'Mis Pacientes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_filteredPatients.length} pacientes asignados',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadPatients,
            tooltip: 'Actualizar lista',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildPatientsContent(),
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
            'Cargando pacientes...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsContent() {
    return RefreshIndicator(
      onRefresh: _loadPatients,
      color: Color(0xFF4A90E2),
      child: Column(
        children: [
          // Header con gradiente
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E3A5F),
                  Color(0xFF2D5082),
                  Color(0xFF4A90E2),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestiona a tus pacientes',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _filteredPatients.isEmpty
                      ? 'Sin pacientes asignados'
                      : '${_filteredPatients.length} ${_filteredPatients.length == 1 ? 'paciente' : 'pacientes'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Barra de búsqueda
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar pacientes...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Alerta de invitaciones pendientes
          if (!_isLoadingInvitations && _invitacionesPendientes.isNotEmpty)
            _buildInvitationAlert(),

          // Contenido principal
          Expanded(
            child: _buildPatientsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsList() {
    final filteredPatients = _filteredPatients;
    
    if (filteredPatients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isNotEmpty ? 'Sin resultados' : 'Sin pacientes asignados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty 
                    ? 'No se encontraron pacientes que coincidan con la búsqueda'
                    : 'Los pacientes aparecerán aquí cuando te sean asignados',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty) ...[  
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Limpiar búsqueda'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: filteredPatients.length,
      itemBuilder: (context, index) {
        final patient = filteredPatients[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(UserModel patient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar del paciente
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.teal[400]!, Colors.teal[600]!],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Información del paciente
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.nombreCompleto.isEmpty ? 'Sin nombre' : patient.nombreCompleto,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patient.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      patient.role.toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Botón de acciones
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) => _handlePatientAction(value, patient),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Ver detalles'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reminders',
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Recordatorios'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(Icons.analytics, size: 18, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Estadísticas'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePatientAction(String action, UserModel patient) {
    switch (action) {
      case 'view':
        _showPatientDetails(patient);
        break;
      case 'reminders':
        _showPatientReminders(patient);
        break;
      case 'stats':
        _showPatientStats(patient);
        break;
    }
  }

  void _showPatientDetails(UserModel patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(patient.nombreCompleto.isEmpty ? 'Paciente' : patient.nombreCompleto),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Email:', patient.email),
            _buildDetailRow('Rol:', patient.role),
            if (patient.nombreCompleto.isNotEmpty)
              _buildDetailRow('Nombre:', patient.nombreCompleto),
            SizedBox(height: 16),
            Text(
              'Funciones disponibles:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Ver recordatorios'),
            Text('• Generar reportes'),
            Text('• Estadísticas de adherencia'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPatientReminders(patient);
            },
            child: Text('Ver Recordatorios'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showPatientReminders(UserModel patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CuidadorRecordatoriosPacienteDetalleScreen(
          paciente: patient,
        ),
      ),
    );
  }

  void _showPatientStats(UserModel patient) async {
    // Mostrar loading primero
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
      ),
    );

    try {
      // Obtener estadísticas del paciente
      final stats = await _cuidadorService.getEstadisticasPaciente(patient.userId!);
      
      // Cerrar loading
      Navigator.pop(context);
      
      // Mostrar estadísticas
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Estadísticas de ${patient.persona.nombres.isEmpty ? 'Paciente' : patient.persona.nombres}',
            style: TextStyle(fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total de recordatorios:', '${stats['totalRecordatorios']}', Icons.list_alt, Colors.blue),
                _buildStatRow('Completados:', '${stats['completados']}', Icons.check_circle, Colors.green),
                _buildStatRow('Pendientes:', '${stats['pendientes']}', Icons.schedule, Colors.orange),
                _buildStatRow('Vencidos:', '${stats['vencidos']}', Icons.warning, Colors.red),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getAdherenciaColor(stats['adherencia']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getAdherenciaColor(stats['adherencia']).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: _getAdherenciaColor(stats['adherencia']),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Adherencia: ${stats['adherencia']}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getAdherenciaColor(stats['adherencia']),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showPatientReminders(patient);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A90E2),
                foregroundColor: Colors.white,
              ),
              child: Text('Ver Recordatorios'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Cerrar loading en caso de error
      Navigator.pop(context);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('No se pudieron cargar las estadísticas del paciente'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }
  
  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getAdherenciaColor(int adherencia) {
    if (adherencia >= 80) return Colors.green;
    if (adherencia >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildInvitationAlert() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InvitacionesCuidadorScreen(),
              ),
            ).then((_) {
              // Recargar invitaciones cuando regrese
              _loadInvitations();
            });
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mail,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '¡Nuevas Solicitudes!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_invitacionesPendientes.length}',
                              style: TextStyle(
                                color: Colors.purple[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        _invitacionesPendientes.length == 1
                            ? 'Tienes 1 invitación pendiente de un paciente'
                            : 'Tienes ${_invitacionesPendientes.length} invitaciones pendientes de pacientes',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Toca para ver solicitudes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
