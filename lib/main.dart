import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'providers/app_state_provider.dart';
import 'screens/home_screen.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await SupabaseService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: const SeaTrackApp(),
    ),
  );
}

class SeaTrackApp extends StatefulWidget {
  const SeaTrackApp({super.key});

  @override
  State<SeaTrackApp> createState() => _SeaTrackAppState();
}

class _SeaTrackAppState extends State<SeaTrackApp> {
  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() async {
    final isGranted = await NotificationListenerService.isPermissionGranted();
    if (isGranted) {
      NotificationListenerService.notificationsStream.listen((event) {
        if (!mounted) return;
        final provider = Provider.of<AppStateProvider>(context, listen: false);
        NotificationService.processNotification(event, (logMsg) {
          provider.addLog(logMsg);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeaTrack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: Colors.indigo,
          secondary: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
