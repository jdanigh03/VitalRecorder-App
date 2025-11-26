import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/firebase_options.dart';  // generado por flutterfire configure
import 'splash_screen.dart';    // tu pantalla de splash (animación / logo)
import 'screens/auth_wrapper.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome.dart';
import 'screens/cuidador_dashboard.dart';
import 'screens/bracelet_setup_screen.dart';
import 'screens/bracelet_control_screen.dart';

import 'package:vital_recorder_app/services/notification_service.dart';
import 'package:vital_recorder_app/services/background_ble_service_simple.dart';
import 'package:vital_recorder_app/services/bracelet_service.dart';
import 'package:vital_recorder_app/background_polling_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Workmanager para polling en segundo plano
  await BackgroundPollingService.initialize();

  // Inicializar localización antes de Firebase
  await initializeDateFormatting('es_ES', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar el servicio de notificaciones (no bloquear app si falla o tarda por falta de internet)
  final NotificationService notificationService = NotificationService();
  notificationService.initNotifications().catchError((e) {
    print('Error inicializando notificaciones: $e');
  });
  
  // Inicializar servicio BLE en segundo plano
  try {
    await BackgroundBleService.initialize();
    print('Servicio BLE en segundo plano inicializado');
  } catch (e) {
    print('Error inicializando servicio BLE: $e');
  }
  
  // Inicializar BraceletService global (escucha BLE desde toda la app)
  try {
    final braceletService = BraceletService();
    await braceletService.initialize();
    print('BraceletService global inicializado');
  } catch (e) {
    print('Error inicializando BraceletService: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vital Recorder',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/auth-wrapper': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/cuidador-dashboard': (context) => CuidadorDashboard(),
        '/bracelet-setup': (context) => const BraceletSetupScreen(),
        '/bracelet-control': (context) => const BraceletControlScreen(),
      },
    );
  }
}
