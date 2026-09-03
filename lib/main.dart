import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'database/app_database.dart';
import 'providers/app_providers.dart';
import 'services/db_migrator.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/widgets/recovery_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  await windowManager.setMinimumSize(const Size(900, 600));
  await windowManager.setSize(const Size(1200, 800));
  await windowManager.center();
  await windowManager.setTitle('Chromodoro');
  await windowManager.setPreventClose(true);

  if (Platform.environment['CHROMODORO_SKIP_MIGRATE'] != '1') {
    await _migrateLegacyData();
  }

  runApp(const ProviderScope(child: ChromodoroApp()));
}

Future<void> _migrateLegacyData() async {
  final docs = await getApplicationDocumentsDirectory();
  final destDb = AppDatabase(path: p.join(docs.path, 'chromodoro.db'));
  final migrator = DbMigrator(destDb);
  try {
    await migrator.migrateIfNeeded();
  } finally {
    await migrator.close();
  }
}

class ChromodoroApp extends ConsumerStatefulWidget {
  const ChromodoroApp({super.key});

  @override
  ConsumerState<ChromodoroApp> createState() => _ChromodoroAppState();
}

class _ChromodoroAppState extends ConsumerState<ChromodoroApp> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await ref.read(settingsNotifierProvider.notifier).load();
    if (!mounted) return;
    // After the first frame, check for an unfinished session from a previous run.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecovery());
  }

  Future<void> _checkRecovery() async {
    final running = await ref.read(sessionRepositoryProvider).getRunning();
    if (running == null || !mounted) return;

    // Resolve project name.
    final project = await ref.read(projectRepositoryProvider).get(running.projectId);
    if (!mounted) return;
    final elapsed = running.runningSince != null
        ? DateTime.now().difference(running.runningSince!).inSeconds
        : DateTime.now().difference(running.startedAt).inSeconds;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecoveryDialog(
        projectName: project?.name ?? 'Project',
        startedAt: running.startedAt,
        elapsedSeconds: elapsed > 0 ? elapsed : 0,
      ),
    );
    if (!mounted) return;
    final repo = ref.read(sessionRepositoryProvider);
    switch (choice) {
      case 'finish':
        await repo.endSession(
          id: running.id,
          duration: elapsed.toDouble(),
          status: 'interrupted',
        );
        break;
      case 'discard':
        await repo.delete(running.id);
        break;
      case 'resume':
      default:
        // Keep the running session; it will show as active on the dashboard.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chromodoro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6FA5),
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6FA5),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Inter',
      ),
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
    );
  }
}