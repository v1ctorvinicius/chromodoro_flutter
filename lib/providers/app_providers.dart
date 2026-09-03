import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart' as db;
import '../models/project.dart' as models;
import '../models/note.dart' as note_models;
import '../repositories/project_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/timer_service.dart';
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
  }
}

// Timer service provider (single stable instance; settings apply on next use)
final timerServiceProvider = Provider<TimerService>((ref) {
  final sessionRepo = ref.read(sessionRepositoryProvider);
  final settings = ref.read(settingsProvider).value ?? const AppSettings();
  return TimerService(sessionRepo, settings);
});

// Project list stream provider
final projectsProvider = StreamProvider<List<models.Project>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.watchAll();
});

// Project summaries provider (combines project data with stats)
final projectSummariesProvider = FutureProvider<List<ProjectSummary>>((ref) async {
  // Recompute whenever the projects stream emits (insert/update/archive).
  ref.watch(projectsProvider);
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
// Returns map of projectId -> parked session id for projects that have a
// running session parked (running but not actively timing).
final parkedSessionsProvider = StreamProvider<Map<int, int>>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return Stream.periodic(const Duration(seconds: 1)).asyncMap((_) async {
    final running = await repo.getRunning();
    if (running == null) return <int, int>{};
    return <int, int>{};
  });
});

// ---- Project view providers ----

final sessionsForProjectProvider =
    StreamProvider.autoDispose.family<List<db.Session>, int>((ref, id) {
  return ref.watch(sessionRepositoryProvider).watchForProject(id);
});

final contributionsForProjectProvider =
    FutureProvider.autoDispose.family<List<db.Contribution>, int>(
        (ref, id) {
  return ref.watch(sessionRepositoryProvider).getContributionsForProject(id);
});

final notesForProjectProvider =
    StreamProvider.autoDispose.family<List<note_models.Note>, int>((ref, id) {
  return ref.watch(noteRepositoryProvider).watchForProject(id);
});

final recentSessionProvider =
    FutureProvider.autoDispose.family<db.Session?, int>((ref, id) async {
  final list = await ref.watch(sessionRepositoryProvider).getForProject(id);
  return list.isEmpty ? null : list.first;
});

final totalSecondsForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  return sessions
      .where((s) => s.status == 'completed')
      .fold<int>(0, (sum, s) => sum + (s.duration ?? 0).round());
});

final todaySecondsForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return sessions
      .where((s) => s.status == 'completed' && !s.startedAt.isBefore(today))
      .fold<int>(0, (sum, s) => sum + (s.duration ?? 0).round());
});

final sessionCountForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  return sessions.where((s) => s.status == 'completed').length;
});

final contribCountForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) {
  return ref.watch(projectRepositoryProvider).getContributionCountForProject(id);
});

final notesCountForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final notes = await ref.watch(noteRepositoryProvider).getForProject(id);
  return notes.length;
});
