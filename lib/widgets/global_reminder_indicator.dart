import 'package:flutter/material.dart';
import '../services/bracelet_service.dart';

/// Widget que muestra un indicador de recordatorio activo
/// Se puede colocar en cualquier pantalla de la app
class GlobalReminderIndicator extends StatefulWidget {
  const GlobalReminderIndicator({Key? key}) : super(key: key);

  @override
  State<GlobalReminderIndicator> createState() => _GlobalReminderIndicatorState();
}

class _GlobalReminderIndicatorState extends State<GlobalReminderIndicator> {
  final BraceletService _braceletService = BraceletService();
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _braceletService,
      builder: (context, child) {
        // Solo mostrar si hay recordatorio activo
        if (!_braceletService.hasActiveReminder) {
          return const SizedBox.shrink();
        }
        
        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.withOpacity(0.8), Colors.deepOrange.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icono parpadeante
              _BlinkingIcon(),
              
              const SizedBox(width: 12),
              
              // Información del recordatorio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🔔 Recordatorio Activo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _braceletService.activeReminderTitle ?? 'Sin título',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Botón para ir a control de manilla
              IconButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/bracelet-control');
                },
                icon: Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Ir a Control de Manilla',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Icono que parpadea para llamar la atención
class _BlinkingIcon extends StatefulWidget {
  @override
  State<_BlinkingIcon> createState() => _BlinkingIconState();
}

class _BlinkingIconState extends State<_BlinkingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.watch,
              color: Colors.white,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}