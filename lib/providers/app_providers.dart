import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart' as db;
import '../models/project.dart' as models;
import '../models/note.dart' as note_models;
import '../repositories/project_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/timer_service.dart';
import '../services/notification_service.dart';
import '../services/tray_service.dart';
import '../services/window_prefs.dart';
import '../services/window_service.dart';
import '../models/app_settings.dart';

// Database provider
final databaseProvider = Provider<db.AppDatabase>((ref) {
  return db.AppDatabase();
});

// Repository providers
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

// Window geometry / mini position persistence.
final windowPrefsProvider = Provider<WindowPrefs>((ref) {
  return WindowPrefs(ref.watch(settingsRepositoryProvider));
});

// Settings provider
final settingsProvider = FutureProvider<AppSettings>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.load();
});

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return const AppSettings();
  }

  Future<void> load() async {
    final repo = ref.read(settingsRepositoryProvider);
    state = await repo.load();
  }

  Future<void> save(AppSettings settings) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.save(settings);
    state = settings;
    // Propagate new settings to the active timer.
    ref.read(timerServiceProvider).updateSettings(settings);
  }
}

// Timer service provider (single stable instance; settings apply on next use)
final timerServiceProvider = Provider<TimerService>((ref) {
  final sessionRepo = ref.read(sessionRepositoryProvider);
  final settings = ref.read(settingsProvider).value ?? const AppSettings();
  final timer = TimerService(sessionRepo, settings);
  timer.onPhaseComplete = (title, body) {
    final current = ref.read(settingsNotifierProvider);
    if (!current.soundAlerts) return;
    ref.read(notificationServiceProvider).show(
          id: 1001,
          title: title,
          body: body,
        );
  };
  return timer;
});

// Notification service provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// System tray service provider
final trayServiceProvider = Provider<TrayService>((ref) {
  final tray = TrayService();

  tray.onToggleWindow = toggleAppWindow;

  tray.onToggleTimer = () {
    final timer = ref.read(timerServiceProvider);
    if (timer.isRunning) {
      timer.pause();
    } else if (timer.state == TimerState.paused) {
      timer.resume();
    }
  };

  tray.onCompletePhase = () {
    final timer = ref.read(timerServiceProvider);
    if (timer.isRunning) {
      timer.completePhase();
    }
  };

  tray.onToggleMini = () {
    ref.read(miniModeProvider.notifier).toggle();
  };

  tray.onQuit = () async {
    if (!ref.read(miniModeProvider)) {
      await ref.read(windowPrefsProvider).saveCurrentGeometry();
    }
    quitApp();
  };

  tray.tooltipBuilder = () {
    final timer = ref.read(timerServiceProvider);
    return 'Chromodoro - ${timer.isRunning ? timer.formattedTime : 'idle'}';
  };

  return tray;
});

// Mini "domino" window mode: true while the window is shrunk to the compact
// always-on-top pill. Drives both the window state and the app UI.
final miniModeProvider =
    NotifierProvider<MiniModeNotifier, bool>(MiniModeNotifier.new);

class MiniModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> enter() async {
    final position = await ref.read(windowPrefsProvider).restoreSavedMiniPosition();
    await enterMiniWindow(position: position);
    state = true;
  }

  Future<void> exit() async {
    try {
      final pos = await currentWindowPosition();
      await ref.read(windowPrefsProvider).saveMiniPosition(pos);
    } catch (_) {
      // Best-effort.
    }
    await exitMiniWindow();
    state = false;
  }

  Future<void> toggle() async {
    if (state) {
      await exit();
    } else {
      await enter();
    }
  }
}

// Set to true to ask the dashboard (full window) to open the "switch project"
// picker after exiting mini mode. The mini window is too small to host a menu.
final miniSwitchRequestedProvider =
    NotifierProvider<MiniSwitchRequestedNotifier, bool>(
        MiniSwitchRequestedNotifier.new);

class MiniSwitchRequestedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void consume() => state = false;
}

// Project list stream provider
final projectsProvider = StreamProvider<List<models.Project>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchAll();
});

// Project summaries provider (combines project data with stats)
final projectSummariesProvider = FutureProvider<List<ProjectSummary>>((ref) async {
  // Recompute whenever the projects stream emits (insert/update/archive).
  ref.watch(projectsProvider);
  // Recompute whenever sessions/contributions/notes change.
  ref.watch(dbActivityProvider);
  final projectRepo = ref.watch(projectRepositoryProvider);
  final noteRepo = ref.watch(noteRepositoryProvider);

  final projects = await projectRepo.getAll();
  final totals = await projectRepo.getTotalSecondsPerProject();
  final counts = await projectRepo.getSessionCountPerProject();
  final lastActivities = await projectRepo.getLastActivityPerProject();
  final todayTotals = await projectRepo.getTodaySecondsPerProject();

  final summaries = <ProjectSummary>[];
  for (final project in projects) {
    final id = project.id;
    if (id == null) continue;
    final totalSecs = totals[id] ?? 0;
    final sessionCount = counts[id] ?? 0;
    final lastActivity = lastActivities[id];
    final todaySecs = todayTotals[id] ?? 0;
    final contribCount = await projectRepo.getContributionCountForProject(id);
    final notes = await noteRepo.getForProject(id);

    summaries.add(ProjectSummary(
      project: project,
      totalSeconds: totalSecs,
      sessionCount: sessionCount,
      contributionCount: contribCount,
      lastActivity: lastActivity,
      todaySeconds: todaySecs,
      notesCount: notes.length,
    ));
  }

  return summaries;
});

class ProjectSummary {
  final models.Project project;
  final int totalSeconds;
  final int sessionCount;
  final int contributionCount;
  final DateTime? lastActivity;
  final int todaySeconds;
  final int notesCount;

  const ProjectSummary({
    required this.project,
    required this.totalSeconds,
    required this.sessionCount,
    required this.contributionCount,
    required this.lastActivity,
    required this.todaySeconds,
    required this.notesCount,
  });

  int? get id => project.id;
  String get name => project.name;
  String get status => project.status;
  String get description => project.description ?? '';
  DateTime get createdAt => project.createdAt;
  String get goalDaysOfWeek => project.goalDaysOfWeek;
  double get dailyGoalMinutes => project.dailyGoalMinutes;
  double get weeklyGoalMinutes => project.weeklyGoalMinutes;
  double get monthlyGoalMinutes => project.monthlyGoalMinutes;
}

// Active session provider
final activeSessionProvider = StreamProvider<db.Session?>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return Stream.periodic(const Duration(milliseconds: 500))
      .asyncMap((_) => repo.getRunning());
});

// Parked sessions provider
// Returns map of projectId -> parked elapsed seconds (the stored, frozen
// duration) for projects that have a running session parked.
final parkedSessionsProvider = StreamProvider<Map<int, int>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
    final allParked = await repo.getAllParked();
    final map = <int, int>{};
    final seen = <int>{};
    for (final s in allParked) {
      if (seen.add(s.projectId)) {
        final elapsed = (s.duration ?? 0.0).round();
        map[s.projectId] = elapsed > 0 ? elapsed : 0;
      }
    }
    return map;
  });
});

// Global today/this-week totals (completed + interrupted), like Python's
// `global_totals`. Used by the dashboard footer.
final globalTotalsProvider = FutureProvider<({int today, int week})>((ref) {
  ref.watch(dbActivityProvider);
  return ref.watch(projectRepositoryProvider).getGlobalTotals();
});

// Per-day totals for the current week (Mon..Sun), like Python's
// `weekly_daily_totals`. Used by the dashboard week bar.
final weeklyDailyTotalsProvider = FutureProvider<List<int>>((ref) {
  ref.watch(dbActivityProvider);
  return ref.watch(projectRepositoryProvider).getWeeklyDailyTotals();
});

// ---- Project view providers ----

/// Emits whenever sessions, contributions, or notes change. Cached providers
/// (dashboard summaries, contributions, counts, last activity, ...) watch this
/// so they recompute automatically instead of going stale.
final dbActivityProvider = StreamProvider<int>((ref) {
  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final noteRepo = ref.watch(noteRepositoryProvider);
  final controller = StreamController<int>();
  final subs = <StreamSubscription<int>>[
    sessionRepo
        .watchSessionActivityStamp()
        .listen((e) => controller.add(e)),
    sessionRepo
        .watchContributionActivityStamp()
        .listen((e) => controller.add(e)),
    noteRepo.watchNoteActivityStamp().listen((e) => controller.add(e)),
  ];
  controller.onCancel = () {
    for (final s in subs) {
      s.cancel();
    }
  };
  return controller.stream;
});

final sessionsForProjectProvider =
    StreamProvider.autoDispose.family<List<db.Session>, int>((ref, id) {
  return ref.watch(sessionRepositoryProvider).watchForProject(id);
});

final contributionsForProjectProvider =
    FutureProvider.autoDispose.family<List<db.Contribution>, int>(
        (ref, id) async {
  ref.watch(dbActivityProvider);
  return ref.watch(sessionRepositoryProvider).getContributionsForProject(id);
});

final notesForProjectProvider =
    StreamProvider.autoDispose.family<List<note_models.Note>, int>((ref, id) {
  return ref.watch(noteRepositoryProvider).watchForProject(id);
});

final recentSessionProvider =
    FutureProvider.autoDispose.family<db.Session?, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  return sessions.isEmpty ? null : sessions.first;
});

final totalSecondsForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  return sessions
      .where((s) => s.status == 'completed' || s.status == 'interrupted')
      .fold<int>(0, (sum, s) => sum + (s.duration ?? 0).round());
});

final todaySecondsForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return sessions
      .where((s) =>
          (s.status == 'completed' || s.status == 'interrupted') &&
          !s.startedAt.isBefore(today))
      .fold<int>(0, (sum, s) => sum + (s.duration ?? 0).round());
});

final sessionCountForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  return sessions
      .where((s) => s.status == 'completed' || s.status == 'interrupted')
      .length;
});

final contribCountForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  ref.watch(dbActivityProvider);
  return ref.watch(projectRepositoryProvider).getContributionCountForProject(id);
});

final notesCountForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final notes = ref.watch(notesForProjectProvider(id)).value ?? [];
  return notes.length;
});
