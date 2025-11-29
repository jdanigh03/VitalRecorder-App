import 'package:flutter/material.dart';
import 'editar_cuidador.dart';
import '../models/cuidador.dart';
import '../models/invitacion_cuidador.dart';
import '../services/cuidador_service.dart';
import '../services/invitacion_service.dart';
import 'welcome.dart';
import 'historial.dart';
import 'ajustes.dart';

class AsignarCuidadorScreen extends StatefulWidget {
  const AsignarCuidadorScreen({Key? key}) : super(key: key);

  @override
  State<AsignarCuidadorScreen> createState() => _AsignarCuidadorScreenState();
}

class _AsignarCuidadorScreenState extends State<AsignarCuidadorScreen> {
  int _selectedIndex = 1; // Cuidadores es el índice 1
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _relacionSeleccionada = 'Familiar';

  final List<String> _relaciones = [
    'Familiar',
    'Hijo/a',
    'Padre/Madre',
    'Esposo/a',
    'Cuidador profesional',
    'Amigo/a',
    'Enfermero/a',
    'Médico',
    'Otro',
  ];

  List<Cuidador> _cuidadoresAsignados = [];
  List<InvitacionCuidador> _invitacionesEnviadas = [];
  final CuidadorService _cuidadorService = CuidadorService();
  final InvitacionService _invitacionService = InvitacionService();
  bool _isLoading = true;
  bool _isSendingInvitation = false;

  @override
  void initState() {
    super.initState();
    _cargarCuidadores();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _cargarCuidadores() async {
    try {
      setState(() => _isLoading = true);
      final cuidadores = await _cuidadorService.obtenerCuidadores();
      final invitaciones = await _invitacionService.getInvitacionesEnviadas();
      setState(() {
        _cuidadoresAsignados = cuidadores;
        _invitacionesEnviadas = invitaciones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error cargando datos: $e');
      _mostrarErrorSnackBar('Error al cargar los datos');
    }
  }

  Future<void> _cargarInvitaciones() async {
    try {
      final invitaciones = await _invitacionService.getInvitacionesEnviadas();
      setState(() {
        _invitacionesEnviadas = invitaciones;
      });
    } catch (e) {
      print('Error cargando invitaciones: $e');
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

  Future<void> _enviarInvitacion() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSendingInvitation = true);
    
    try {
      // Enviar invitación al cuidador (solo email y relación)
      final invitacionId = await _invitacionService.enviarInvitacion(
        cuidadorEmail: _emailController.text.trim(),
        cuidadorNombre: 'Cuidador', // Se actualizará con datos reales del registro
        relacion: _relacionSeleccionada,
      );
      
      if (invitacionId != null) {
        // Recargar datos
        await _cargarCuidadores();
        await _cargarInvitaciones();
        
        // Limpiar formulario
        _emailController.clear();
        setState(() {
          _relacionSeleccionada = 'Familiar';
          _isSendingInvitation = false;
        });

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.send, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Invitación enviada exitosamente. El cuidador recibirá una notificación para aceptar.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSendingInvitation = false);
      Navigator.pop(context);
      _mostrarErrorSnackBar('Error al enviar la invitación: ${e.toString()}');
    }
  }



  void _mostrarFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person_add,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Invitar Cuidador',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[600], size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Sistema de Invitación',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Solo necesitas el correo del cuidador ya registrado. Él recibirá una notificación para aceptar ser tu cuidador.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo del cuidador registrado',
                    hintText: 'cuidador@email.com',
                    prefixIcon: Icon(Icons.email, color: Color(0xFF4A90E2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    helperText: 'El cuidador debe estar previamente registrado',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa el correo del cuidador';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Ingresa un correo válido';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _relacionSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Relación con el paciente',
                    prefixIcon: Icon(Icons.people, color: Color(0xFF4A90E2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: _relaciones.map((relacion) {
                    return DropdownMenuItem(
                      value: relacion,
                      child: Text(relacion),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _relacionSeleccionada = value!;
                    });
                  },
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingInvitation ? null : _enviarInvitacion,
                    icon: _isSendingInvitation 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _isSendingInvitation ? 'Enviando...' : 'Enviar Invitación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),

              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        automaticallyImplyLeading: false,
        title: const Text(
          'Asignar Cuidador',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
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
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.people,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Gestiona tus Cuidadores',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Los cuidadores recibirán notificaciones de tus recordatorios y podrán ayudarte a gestionar tu salud',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cuidadores Asignados',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF4A90E2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_cuidadoresAsignados.length}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (_isLoading)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Cargando cuidadores...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_cuidadoresAsignados.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_add_disabled,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No tienes cuidadores asignados',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Agrega un cuidador para que te ayude con tus recordatorios',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._cuidadoresAsignados.map((cuidador) {
                      return _buildCuidadorCard(cuidador);
                    }).toList(),
                  
                  // Sección de invitaciones enviadas
                  if (_invitacionesEnviadas.isNotEmpty) ...[
                    SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Invitaciones Enviadas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_invitacionesEnviadas.length}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ..._invitacionesEnviadas.map((invitacion) {
                      return _buildInvitacionCard(invitacion);
                    }).toList(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarFormulario,
        backgroundColor: Color(0xFF4A90E2),
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text(
          'Agregar Cuidador',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Cuidadores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _buildCuidadorCard(Cuidador cuidador) {
    final color = Color(cuidador.colorPorRelacion);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      cuidador.iniciales,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cuidador.nombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              cuidador.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Text(
                            cuidador.telefono,
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
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Colors.blue),
                          SizedBox(width: 12),
                          Text('Editar'),
                        ],
                      ),
                      value: 'edit',
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.notifications, size: 20, color: Colors.orange),
                          SizedBox(width: 12),
                          Text('Notificaciones'),
                        ],
                      ),
                      value: 'notifications',
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Eliminar'),
                        ],
                      ),
                      value: 'delete',
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _mostrarDialogoEliminar(cuidador);
                    } else if (value == 'edit') {
                      _editarCuidador(cuidador);
                    } else if (value == 'notifications') {
                      _mostrarDialogoNotificaciones(cuidador);
                    }
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.label, size: 16, color: color),
                    SizedBox(width: 8),
                    Text(
                      'Relación:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    cuidador.relacion,
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editarCuidador(Cuidador cuidador) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarCuidadorScreen(cuidador: cuidador),
      ),
    );
    
    if (resultado != null) {
      try {
        // Crear cuidador actualizado con los nuevos datos
        final cuidadorActualizado = Cuidador(
          id: cuidador.id,
          nombre: resultado['nombre'] ?? cuidador.nombre,
          email: resultado['email'] ?? cuidador.email,
          telefono: resultado['telefono'] ?? cuidador.telefono,
          relacion: resultado['relacion'] ?? cuidador.relacion,
          notificaciones: cuidador.notificaciones,
          fechaCreacion: cuidador.fechaCreacion,
          fechaActualizacion: DateTime.now(),
        );
        
        // Actualizar en Firebase
        await _cuidadorService.actualizarCuidador(cuidadorActualizado);
        
        // Recargar lista desde Firebase
        await _cargarCuidadores();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Cuidador actualizado exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        _mostrarErrorSnackBar('Error al actualizar el cuidador: ${e.toString()}');
      }
    }
  }

  void _mostrarDialogoNotificaciones(Cuidador cuidador) {
    // Estado local para las notificaciones
    bool medicamentos = cuidador.notificaciones.recordatoriosMedicamentos;
    bool omitidos = cuidador.notificaciones.recordatoriosOmitidos;
    bool resumen = cuidador.notificaciones.resumenDiario;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications, color: Color(0xFF4A90E2)),
              SizedBox(width: 12),
              Text('Notificaciones'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurar notificaciones para ${cuidador.nombre}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              CheckboxListTile(
                title: Text('Recordatorios de medicamentos'),
                value: medicamentos,
                onChanged: isSaving ? null : (value) {
                  setState(() {
                    medicamentos = value ?? false;
                  });
                },
                activeColor: Color(0xFF4A90E2),
              ),
              CheckboxListTile(
                title: Text('Recordatorios omitidos'),
                value: omitidos,
                onChanged: isSaving ? null : (value) {
                  setState(() {
                    omitidos = value ?? false;
                  });
                },
                activeColor: Color(0xFF4A90E2),
              ),
              CheckboxListTile(
                title: Text('Resumen diario'),
                value: resumen,
                onChanged: isSaving ? null : (value) {
                  setState(() {
                    resumen = value ?? false;
                  });
                },
                activeColor: Color(0xFF4A90E2),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setState(() {
                  isSaving = true;
                });
                
                try {
                  // Crear cuidador actualizado con nuevas preferencias
                  final cuidadorActualizado = Cuidador(
                    id: cuidador.id,
                    nombre: cuidador.nombre,
                    email: cuidador.email,
                    telefono: cuidador.telefono,
                    relacion: cuidador.relacion,
                    notificaciones: NotificacionesCuidador(
                      recordatoriosMedicamentos: medicamentos,
                      recordatoriosOmitidos: omitidos,
                      resumenDiario: resumen,
                    ),
                    fechaCreacion: cuidador.fechaCreacion,
                    fechaActualizacion: DateTime.now(),
                  );
                  
                  // Actualizar en Firebase
                  await _cuidadorService.actualizarCuidador(cuidadorActualizado);
                  
                  // Recargar lista
                  await _cargarCuidadores();
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Preferencias de notificación guardadas'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                } catch (e) {
                  setState(() {
                    isSaving = false;
                  });
                  _mostrarErrorSnackBar('Error al guardar las preferencias: ${e.toString()}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4A90E2),
              ),
              child: isSaving 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
        break;
      case 1:
        // Ya estamos en Cuidadores
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HistorialScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AjustesScreen()),
        );
        break;
    }
  }

  void _mostrarDialogoEliminar(Cuidador cuidador) {
    bool isDeleting = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Text('Eliminar Cuidador'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar a ${cuidador.nombre}?',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El cuidador será marcado como inactivo. Podrás restaurarlo más tarde si lo necesitas.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isDeleting ? null : () async {
                setState(() {
                  isDeleting = true;
                });
                
                try {
                  // Eliminar (marcar como inactivo) en Firebase
                  await _cuidadorService.eliminarCuidador(cuidador.id);
                  
                  // Recargar lista
                  await _cargarCuidadores();
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Cuidador eliminado exitosamente'),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      action: SnackBarAction(
                        label: 'Deshacer',
                        textColor: Colors.white,
                        onPressed: () async {
                          try {
                            await _cuidadorService.restaurarCuidador(cuidador.id);
                            await _cargarCuidadores();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cuidador restaurado'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            _mostrarErrorSnackBar('Error al restaurar: ${e.toString()}');
                          }
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  setState(() {
                    isDeleting = false;
                  });
                  _mostrarErrorSnackBar('Error al eliminar el cuidador: ${e.toString()}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitacionCard(InvitacionCuidador invitacion) {
    // Definir color basado en el estado
    Color getColorByStatus(EstadoInvitacion estado) {
      switch (estado) {
        case EstadoInvitacion.pendiente:
          return Colors.orange;
        case EstadoInvitacion.aceptada:
          return Colors.green;
        case EstadoInvitacion.rechazada:
          return Colors.red;
        case EstadoInvitacion.cancelada:
          return Colors.grey;
      }
    }

    // Obtener ícono basado en el estado
    IconData getIconByStatus(EstadoInvitacion estado) {
      switch (estado) {
        case EstadoInvitacion.pendiente:
          return Icons.schedule;
        case EstadoInvitacion.aceptada:
          return Icons.check_circle;
        case EstadoInvitacion.rechazada:
          return Icons.cancel;
        case EstadoInvitacion.cancelada:
          return Icons.help;
      }
    }

    final color = getColorByStatus(invitacion.estado);
    final icon = getIconByStatus(invitacion.estado);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitacion.cuidadorNombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              invitacion.cuidadorEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 6),
                          Text(
                            'Enviada ${_formatearFecha(invitacion.fechaEnvio)}',
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
                if (invitacion.estado.toLowerCase() == 'pendiente')
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Cancelar invitación'),
                          ],
                        ),
                        value: 'cancel',
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'cancel') {
                        _cancelarInvitacion(invitacion);
                      }
                    },
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.label, size: 16, color: color),
                    SizedBox(width: 8),
                    Text(
                      'Relación: ${invitacion.relacion}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Text(
                    invitacion.estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  Future<void> _cancelarInvitacion(InvitacionCuidador invitacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Cancelar Invitación'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas cancelar la invitación a ${invitacion.cuidadorNombre}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _invitacionService.cancelarInvitacion(invitacion.id);
        await _cargarInvitaciones();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel, color: Colors.white),
                SizedBox(width: 12),
                Text('Invitación cancelada exitosamente'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } catch (e) {
        _mostrarErrorSnackBar('Error al cancelar la invitación: ${e.toString()}');
      }
    }
  }
}
