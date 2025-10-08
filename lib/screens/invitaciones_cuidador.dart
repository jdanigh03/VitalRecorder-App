import 'package:flutter/material.dart';
import '../models/invitacion_cuidador.dart';
import '../services/invitacion_service.dart';

class InvitacionesCuidadorScreen extends StatefulWidget {
  const InvitacionesCuidadorScreen({Key? key}) : super(key: key);

  @override
  State<InvitacionesCuidadorScreen> createState() => _InvitacionesCuidadorScreenState();
}

class _InvitacionesCuidadorScreenState extends State<InvitacionesCuidadorScreen>
    with SingleTickerProviderStateMixin {
  final InvitacionService _invitacionService = InvitacionService();
  
  late TabController _tabController;
  List<InvitacionCuidador> _todasInvitaciones = [];
  List<InvitacionCuidador> _pendientes = [];
  List<InvitacionCuidador> _procesadas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarInvitaciones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarInvitaciones() async {
    try {
      setState(() => _isLoading = true);
      
      final invitaciones = await _invitacionService.getInvitacionesRecibidas();
      
      setState(() {
        _todasInvitaciones = invitaciones;
        _pendientes = invitaciones.where((inv) => inv.esPendiente).toList();
        _procesadas = invitaciones.where((inv) => !inv.esPendiente).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarErrorSnackBar('Error al cargar las invitaciones: ${e.toString()}');
    }
  }

  void _mostrarErrorSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _responderInvitacion(InvitacionCuidador invitacion, bool aceptar) async {
    try {
      bool success;
      if (aceptar) {
        success = await _invitacionService.aceptarInvitacion(invitacion.id);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('¡Has aceptado ser cuidador de ${invitacion.pacienteNombre}!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Mostrar diálogo para motivo de rechazo
        final motivo = await _mostrarDialogoRechazo(invitacion);
        if (motivo != null) {
          success = await _invitacionService.rechazarInvitacion(
            invitacion.id, 
            motivo: motivo.isEmpty ? null : motivo,
          );
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Has rechazado la invitación'),
                  ],
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        } else {
          return; // Usuario canceló
        }
      }
      
      // Recargar invitaciones
      await _cargarInvitaciones();
    } catch (e) {
      _mostrarErrorSnackBar('Error al procesar la invitación: ${e.toString()}');
    }
  }

  Future<String?> _mostrarDialogoRechazo(InvitacionCuidador invitacion) async {
    final TextEditingController motivoController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.orange),
            SizedBox(width: 12),
            Text('Rechazar Invitación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas rechazar la invitación de ${invitacion.pacienteNombre}?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            TextField(
              controller: motivoController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo del rechazo (opcional)',
                hintText: 'Puedes explicar por qué no puedes aceptar...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, motivoController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        title: const Text(
          'Invitaciones Recibidas',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Pendientes',
              icon: Badge(
                label: Text('${_pendientes.length}'),
                backgroundColor: Colors.orange,
                isLabelVisible: _pendientes.isNotEmpty,
                child: Icon(Icons.schedule),
              ),
            ),
            Tab(
              text: 'Procesadas',
              icon: Badge(
                label: Text('${_procesadas.length}'),
                backgroundColor: Colors.blue,
                isLabelVisible: _procesadas.isNotEmpty,
                child: Icon(Icons.history),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header con información
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
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
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mail,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Invitaciones de Pacientes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Gestiona las solicitudes para ser cuidador',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Contenido de tabs
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cargando invitaciones...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvitacionesList(_pendientes, esPendiente: true),
                      _buildInvitacionesList(_procesadas, esPendiente: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitacionesList(List<InvitacionCuidador> invitaciones, {required bool esPendiente}) {
    if (invitaciones.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                esPendiente ? Icons.mail_outline : Icons.history,
                size: 80,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                esPendiente 
                    ? 'No tienes invitaciones pendientes'
                    : 'No tienes invitaciones procesadas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                esPendiente
                    ? 'Las nuevas solicitudes aparecerán aquí'
                    : 'Las invitaciones aceptadas o rechazadas aparecerán aquí',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarInvitaciones,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: invitaciones.length,
        itemBuilder: (context, index) {
          final invitacion = invitaciones[index];
          return _buildInvitacionCard(invitacion, esPendiente);
        },
      ),
    );
  }

  Widget _buildInvitacionCard(InvitacionCuidador invitacion, bool esPendiente) {
    Color getColorByStatus() {
      if (esPendiente) return Colors.orange;
      switch (invitacion.estado) {
        case EstadoInvitacion.aceptada:
          return Colors.green;
        case EstadoInvitacion.rechazada:
          return Colors.red;
        case EstadoInvitacion.cancelada:
          return Colors.grey;
        default:
          return Colors.orange;
      }
    }

    IconData getIconByStatus() {
      if (esPendiente) return Icons.schedule;
      switch (invitacion.estado) {
        case EstadoInvitacion.aceptada:
          return Icons.check_circle;
        case EstadoInvitacion.rechazada:
          return Icons.cancel;
        case EstadoInvitacion.cancelada:
          return Icons.help;
        default:
          return Icons.schedule;
      }
    }

    final color = getColorByStatus();
    final icon = getIconByStatus();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la tarjeta
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitud de ${invitacion.pacienteNombre}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            invitacion.pacienteEmail,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    invitacion.estadoTexto.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenido de la tarjeta
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información de la relación
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: color, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Relación: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          invitacion.relacion,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Información adicional
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      'Enviada ${_formatearFecha(invitacion.fechaEnvio)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                if (invitacion.telefono != null && invitacion.telefono!.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        invitacion.telefono!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                
                if (invitacion.mensaje != null && invitacion.mensaje!.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.message, size: 16, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text(
                              'Mensaje del paciente:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          invitacion.mensaje!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[800],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Botones de acción para invitaciones pendientes
          if (esPendiente) ...[
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _responderInvitacion(invitacion, false),
                      icon: Icon(Icons.cancel, size: 18),
                      label: Text('Rechazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[700],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _responderInvitacion(invitacion, true),
                      icon: Icon(Icons.check_circle, size: 18),
                      label: Text('Aceptar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'hace ${difference.inMinutes} minutos';
      }
      return 'hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'ayer';
    } else if (difference.inDays < 7) {
      return 'hace ${difference.inDays} días';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }
}
