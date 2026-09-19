import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/activity_log.dart';
import 'providers/listener_controller.dart';
import 'providers/transaction_provider.dart';
import 'providers/update_controller.dart';
import 'repositories/transaction_repository.dart';
import 'screens/home_shell.dart';
import 'services/database_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await Future.wait([
    initializeDateFormatting('id_ID'),
    DatabaseService.open(),
  ]);
  runApp(const SeaTrackApp());
}

class SeaTrackApp extends StatelessWidget {
  const SeaTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ActivityLog()),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(const TransactionRepository())..refresh(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ListenerController(
            ctx.read<TransactionProvider>(),
            ctx.read<ActivityLog>(),
          )..init(),
        ),
        ChangeNotifierProvider(create: (_) => UpdateController()..init()),
      ],
      child: MaterialApp(
        title: 'SeaTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}
