import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';

/// One-time migration that copies data from the legacy Python app database
/// (%APPDATA%\Chromodoro\chromodoro.db, ISO-text dates) into the Drift database
/// (native unix-seconds DateTime storage).
class DbMigrator {
  final AppDatabase _dest;
  final String? _sourcePathOverride;

  DbMigrator(this._dest, {String? sourcePathOverride})
      : _sourcePathOverride = sourcePathOverride;

  static String defaultSourcePath() {
    final appdata = Platform.environment['APPDATA'] ??
        p.join(Platform.environment['USERPROFILE']!, 'AppData', 'Roaming');
    return p.join(appdata, 'Chromodoro', 'chromodoro.db');
  }

  static String newDefaultPath() {
    final docs = Platform.environment['USERPROFILE'] ??
        p.join(Platform.environment['HOME'] ?? '');
    return p.join(docs, 'Documents', 'chromodoro', 'chromodoro.db');
  }

  AppDatabase get destination => _dest;

  Future<bool> migrateIfNeeded() async {
    final sourcePath = _sourcePathOverride ?? defaultSourcePath();
    if (!File(sourcePath).existsSync()) return false;

    final destProjects = await _dest.getAllProjects();
    if (destProjects.isNotEmpty) return false;

    final db = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
    try {
      final count =
          db.select('SELECT COUNT(*) FROM projects').first.values.first as int;
      if (count == 0) return false;
      await _migrate(db);
    } finally {
      db.close();
    }
    return true;
  }

  Future<void> _migrate(Database source) async {
    await _copyProjects(source);
    await _copySessions(source);
    await _copyContributions(source);
    await _copyNotes(source);
  }

  Future<void> _copyProjects(Database source) async {
    final rows = source.select(
      'SELECT id, name, description, status, created_at, daily_goal_minutes, '
      'weekly_goal_minutes, monthly_goal_minutes, goal_days_of_week FROM projects',
    );
    for (final row in rows) {
      await _dest.into(_dest.projects).insert(
            ProjectsCompanion.insert(
              id: Value(row['id'] as int),
              name: row['name'] as String,
              description: Value(row['description'] as String?),
              status: Value(row['status'] as String? ?? 'active'),
              createdAt: _parseDate(row['created_at'] as String?) ?? DateTime.now(),
              dailyGoalMinutes: Value((row['daily_goal_minutes'] as num?)?.toDouble() ?? 0),
              weeklyGoalMinutes: Value((row['weekly_goal_minutes'] as num?)?.toDouble() ?? 0),
              monthlyGoalMinutes: Value((row['monthly_goal_minutes'] as num?)?.toDouble() ?? 0),
              goalDaysOfWeek: Value(row['goal_days_of_week'] as String?),
            ),
          );
    }
  }

  Future<void> _copySessions(Database source) async {
    final rows = source.select(
      'SELECT id, project_id, started_at, ended_at, duration, running_since, status '
      'FROM sessions',
    );
    for (final row in rows) {
      await _dest.into(_dest.sessions).insert(
            SessionsCompanion.insert(
              id: Value(row['id'] as int),
              projectId: row['project_id'] as int,
              startedAt: _parseDate(row['started_at'] as String?) ?? DateTime.now(),
              duration: Value((row['duration'] as num?)?.toDouble()),
              status: Value(row['status'] as String? ?? 'running'),
              endedAt: Value(_parseDate(row['ended_at'] as String?)),
              runningSince: Value(_parseDate(row['running_since'] as String?)),
            ),
          );
    }
  }

  Future<void> _copyContributions(Database source) async {
    final rows = source.select(
      'SELECT id, session_id, title, type, created_at FROM contributions',
    );
    for (final row in rows) {
      await _dest.into(_dest.contributions).insert(
            ContributionsCompanion.insert(
              id: Value(row['id'] as int),
              sessionId: row['session_id'] as int,
              title: row['title'] as String,
              type: Value(row['type'] as String?),
              createdAt: _parseDate(row['created_at'] as String?) ?? DateTime.now(),
            ),
          );
    }
  }

  Future<void> _copyNotes(Database source) async {
    final hasNotes = source
        .select("SELECT name FROM sqlite_master WHERE type='table' AND name='notes'")
        .isNotEmpty;
    if (!hasNotes) return;
    final rows = source.select(
      'SELECT id, project_id, content, created_at, updated_at FROM notes',
    );
    for (final row in rows) {
      await _dest.into(_dest.notes).insert(
            NotesCompanion.insert(
              id: Value(row['id'] as int),
              projectId: row['project_id'] as int,
              content: row['content'] as String,
              createdAt: _parseDate(row['created_at'] as String?) ?? DateTime.now(),
              updatedAt: _parseDate(row['updated_at'] as String?) ?? DateTime.now(),
            ),
          );
    }
  }

  DateTime? _parseDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    return DateTime.tryParse(iso.trim());
  }

  Future<void> close() => _dest.close();
}
