import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bracelet_service.dart';

/// Widget que muestra el estado actual de la manilla y recordatorios activos
class BraceletStatusWidget extends StatelessWidget {
  const BraceletStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<BraceletService>(
      builder: (context, braceletService, child) {
        if (!braceletService.isConnected) {
          return Card(
            color: Colors.grey[100],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: const [
                  Icon(Icons.bluetooth_disabled, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Manilla desconectada',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Manilla conectada
        if (braceletService.hasActiveReminder) {
          return Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.watch, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        'Recordatorio activo en la manilla',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    braceletService.activeReminderTitle ?? 'Sin título',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.touch_app, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Presiona el botón en la manilla para confirmar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // Manilla conectada, sin recordatorios activos
        return Card(
          color: Colors.green[50],
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.bluetooth_connected, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Manilla conectada',
                  style: TextStyle(color: Colors.green),
                ),
                const Spacer(),
                if (braceletService.isSyncing)
                  Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Sincronizando...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget botón para completar recordatorio desde la app
class CompleteReminderButton extends StatelessWidget {
  const CompleteReminderButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<BraceletService>(
      builder: (context, braceletService, child) {
        if (!braceletService.hasActiveReminder) {
          return const SizedBox.shrink();
        }

        return ElevatedButton.icon(
          onPressed: () async {
            try {
              if (braceletService.activeReminderIndex != null) {
                await braceletService.completeReminderOnBracelet(
                  braceletService.activeReminderIndex!
                );
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recordatorio completado desde la app'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error completando recordatorio: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          icon: const Icon(Icons.check_circle),
          label: const Text('Completar desde la app'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }
}