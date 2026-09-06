import 'dart:io';
import 'package:drift/drift.dart';
import '../database/app_database.dart' as db;
import '../models/project.dart' as models;

String _csvEscape(String value) {
  if (value.contains(';') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

class ProjectRepository {
  final db.AppDatabase _db;

  ProjectRepository(this._db);

  Future<int> create({
    required String name,
    String description = '',
    double dailyGoalMinutes = 0,
    double weeklyGoalMinutes = 0,
    double monthlyGoalMinutes = 0,
    List<int>? goalDaysOfWeek,
  }) {
    return _db.into(_db.projects).insert(
      db.ProjectsCompanion(
        name: Value(name),
        description: Value(description),
        status: const Value('active'),
        createdAt: Value(DateTime.now()),
        dailyGoalMinutes: Value(dailyGoalMinutes),
        weeklyGoalMinutes: Value(weeklyGoalMinutes),
        monthlyGoalMinutes: Value(monthlyGoalMinutes),
        goalDaysOfWeek: Value(goalDaysOfWeek?.join(',')),
      ),
    );
  }

  Future<int> update({
    required int id,
    String? name,
    String? description,
    double? dailyGoalMinutes,
    double? weeklyGoalMinutes,
    double? monthlyGoalMinutes,
    List<int>? goalDaysOfWeek,
    String? status,
  }) {
    final companion = db.ProjectsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      dailyGoalMinutes: dailyGoalMinutes != null ? Value(dailyGoalMinutes) : const Value.absent(),
      weeklyGoalMinutes: weeklyGoalMinutes != null ? Value(weeklyGoalMinutes) : const Value.absent(),
      monthlyGoalMinutes: monthlyGoalMinutes != null ? Value(monthlyGoalMinutes) : const Value.absent(),
      goalDaysOfWeek: goalDaysOfWeek != null ? Value(goalDaysOfWeek.join(',')) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
    );
    return (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<int> archive(int id) {
    return (_db.update(_db.projects)..where((t) => t.id.equals(id)))
        .write(db.ProjectsCompanion(status: const Value('archived')));
  }

  Future<models.Project?> get(int id) async {
    final dbProject = await (_db.select(_db.projects)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (dbProject == null) return null;
    return _toModel(dbProject);
  }

  Future<List<models.Project>> getAll({String status = 'active'}) async {
    final dbProjects = await (_db.select(_db.projects)..where((t) => t.status.equals(status))).get();
    return dbProjects.map(_toModel).toList();
  }

  Stream<List<models.Project>> watchAll({String status = 'active'}) {
    return (_db.select(_db.projects)..where((t) => t.status.equals(status)))
        .watch()
        .map((projects) => projects.map(_toModel).toList());
  }

  models.Project _toModel(db.Project p) {
    return models.Project(
      id: p.id,
      name: p.name,
      description: p.description,
      status: p.status,
      createdAt: p.createdAt,
      dailyGoalMinutes: p.dailyGoalMinutes,
      weeklyGoalMinutes: p.weeklyGoalMinutes,
      monthlyGoalMinutes: p.monthlyGoalMinutes,
      goalDaysOfWeek: p.goalDaysOfWeek ?? '',
    );
  }

  Future<Map<int, int>> getTotalSecondsPerProject() async {
    final rows = await _db.customSelect(
      "SELECT project_id, SUM(duration) as total FROM sessions WHERE status IN ('completed', 'interrupted') GROUP BY project_id",
      readsFrom: {_db.sessions},
    ).get();
    return {for (var row in rows) row.read<int>('project_id'): row.read<double>('total').toInt()};
  }

  /// Total non-paused seconds for all sessions started today and this week
  /// (Monday-based), mirroring the Python `global_totals`.
  Future<({int today, int week})> getGlobalTotals() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final rows = await _db.customSelect(
      "SELECT SUM(CASE WHEN started_at >= ? THEN duration ELSE 0 END) AS today,"
      "       SUM(CASE WHEN started_at >= ? THEN duration ELSE 0 END) AS week"
      " FROM sessions WHERE status IN ('completed', 'interrupted')",
      variables: [Variable.withDateTime(today), Variable.withDateTime(weekStart)],
      readsFrom: {_db.sessions},
    ).get();
    final row = rows.isEmpty ? null : rows.first;
    return (
      today: (row?.read<double>('today') ?? 0).round(),
      week: (row?.read<double>('week') ?? 0).round(),
    );
  }

  /// Total seconds per weekday (Monday=0..Sunday=6) for the current week.
  Future<List<int>> getWeeklyDailyTotals() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final rows = await _db.customSelect(
      "SELECT started_at, duration FROM sessions"
      " WHERE status IN ('completed', 'interrupted') AND started_at >= ? AND started_at < ?",
      variables: [Variable.withDateTime(weekStart), Variable.withDateTime(weekEnd)],
      readsFrom: {_db.sessions},
    ).get();
    final perDay = List<int>.filled(7, 0);
    for (final row in rows) {
      final startedAt = row.read<DateTime>('started_at');
      final idx = startedAt.weekday - 1; // Monday=0
      perDay[idx] += row.read<double>('duration').round();
    }
    return perDay;
  }

  /// Exports all sessions to a CSV at [path] (UTF-8 with BOM). Returns row count.
  Future<int> exportSessionsCsv(String path) async {
    final rows = await _db.customSelect(
      "SELECT s.started_at, s.ended_at, s.duration, s.pause_duration, s.status, p.name AS project"
      " FROM sessions s JOIN projects p ON p.id = s.project_id"
      " ORDER BY s.started_at, s.id",
      readsFrom: {_db.sessions, _db.projects},
    ).get();
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('started_at;ended_at;minutes;pause_minutes;status;project');
    for (final row in rows) {
      final startedAt = row.read<DateTime>('started_at');
      final endedAt = row.read<DateTime?>('ended_at');
      final minutes = row.read<int>('duration') / 60.0;
      final pauseMinutes = row.read<int>('pause_duration') / 60.0;
      buffer.writeln([
        startedAt.toIso8601String(),
        endedAt?.toIso8601String() ?? '',
        minutes.toStringAsFixed(2).replaceAll('.', ','),
        pauseMinutes.toStringAsFixed(2).replaceAll('.', ','),
        row.read<String>('status'),
        _csvEscape(row.read<String>('project')),
      ].join(';'));
    }
    await File(path).writeAsString(buffer.toString(), flush: true);
    return rows.length;
  }

  /// Exports all contributions to a CSV at [path] (UTF-8 with BOM). Returns row count.
  Future<int> exportContributionsCsv(String path) async {
    final rows = await _db.customSelect(
      "SELECT c.created_at, c.title, c.type, p.name AS project"
      " FROM contributions c JOIN projects p ON p.id = c.project_id"
      " ORDER BY c.created_at, c.id",
      readsFrom: {_db.contributions, _db.projects},
    ).get();
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('created_at;project;title;type');
    for (final row in rows) {
      final createdAt = row.read<DateTime>('created_at');
      buffer.writeln([
        createdAt.toIso8601String(),
        _csvEscape(row.read<String>('project')),
        _csvEscape(row.read<String>('title')),
        _csvEscape(row.read<String?>('type') ?? ''),
      ].join(';'));
    }
    await File(path).writeAsString(buffer.toString(), flush: true);
    return rows.length;
  }

  /// Creates a consistent snapshot backup of the database at [path].
  Future<void> backupDatabase(String path) async {
    if (File(path).existsSync()) File(path).deleteSync();
    await _db.customStatement('VACUUM INTO ?', [path]);
  }

  Future<Map<int, int>> getSessionCountPerProject() async {
    final rows = await _db.customSelect(
      "SELECT project_id, COUNT(*) as count FROM sessions WHERE status IN ('completed', 'interrupted') GROUP BY project_id",
      readsFrom: {_db.sessions},
    ).get();
    return {for (var row in rows) row.read<int>('project_id'): row.read<int>('count')};
  }

  Future<Map<int, DateTime?>> getLastActivityPerProject() async {
    final rows = await _db.customSelect(
      'SELECT project_id, MAX(started_at) as last FROM sessions GROUP BY project_id',
      readsFrom: {_db.sessions},
    ).get();
    return {
      for (var row in rows)
        row.read<int>('project_id'):
            row.read<DateTime?>('last'),
    };
  }

  Future<Map<int, int>> getTodaySecondsPerProject() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final rows = await _db.customSelect(
      "SELECT project_id, SUM(duration) as total FROM sessions WHERE status IN ('completed', 'interrupted') AND started_at >= ? GROUP BY project_id",
      variables: [Variable.withDateTime(startOfDay)],
      readsFrom: {_db.sessions},
    ).get();
    return {for (var row in rows) row.read<int>('project_id'): row.read<double>('total').toInt()};
  }

  Future<int> getContributionCountForProject(int projectId) async {
    final count = await _db.customSelect(
      'SELECT COUNT(*) as count FROM contributions WHERE session_id IN (SELECT id FROM sessions WHERE project_id = ?)',
      variables: [Variable.withInt(projectId)],
      readsFrom: {_db.contributions, _db.sessions},
    ).get();
    return count.first.read<int>('count');
  }
}