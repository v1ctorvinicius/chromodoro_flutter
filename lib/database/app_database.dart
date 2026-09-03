import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime()();
  RealColumn get dailyGoalMinutes => real().withDefault(const Constant(0.0))();
  RealColumn get weeklyGoalMinutes => real().withDefault(const Constant(0.0))();
  RealColumn get monthlyGoalMinutes => real().withDefault(const Constant(0.0))();
  TextColumn get goalDaysOfWeek => text().nullable()();
}

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  RealColumn get duration => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('running'))();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get runningSince => dateTime().nullable()();
}

class Contributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get type => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text().withLength(min: 1, max: 5000)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class SettingsTable extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Projects, Sessions, Contributions, Notes, SettingsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? path}) : super(_openConnection(path: path));

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from v1 to v2: add goal columns
        if (from < 2) {
          await m.addColumn(projects, projects.dailyGoalMinutes);
          await m.addColumn(projects, projects.weeklyGoalMinutes);
          await m.addColumn(projects, projects.monthlyGoalMinutes);
        }
        // Migration v3: add goal_days_of_week
        if (from < 3) {
          await m.addColumn(projects, projects.goalDaysOfWeek);
        }
        // v4, v5, v6: adjustments to indexes, constraints (no-op for new installs)
        // v7: add notes table
        if (from < 7) {
          await m.createTable(notes);
        }
      },
    );
  }

  // Projects
  Future<int> insertProject(ProjectsCompanion project) => into(projects).insert(project);
  Future<bool> updateProject(ProjectsCompanion project) => update(projects).replace(project);
  Future<int> deleteProject(int id) => (projects.delete()..where((t) => t.id.equals(id))).go();
  Future<Project?> getProject(int id) => (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<Project>> getAllProjects({String status = 'active'}) => (select(projects)..where((t) => t.status.equals(status))).get();
  Stream<List<Project>> watchAllProjects({String status = 'active'}) => (select(projects)..where((t) => t.status.equals(status))).watch();

  // Sessions
  Future<int> insertSession(SessionsCompanion session) => into(sessions).insert(session);
  Future<bool> updateSession(SessionsCompanion session) => update(sessions).replace(session);
  Future<Session?> getSession(int id) => (select(sessions)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<List<Session>> getSessionsForProject(int projectId) => (select(sessions)..where((t) => t.projectId.equals(projectId))..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).get();
  Stream<List<Session>> watchSessionsForProject(int projectId) => (select(sessions)..where((t) => t.projectId.equals(projectId))..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).watch();
  Future<Session?> getRunningSession() => (select(sessions)..where((t) => t.status.equals('running'))..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).getSingleOrNull();
  Future<Session?> getParkedSession(int projectId) => (select(sessions)..where((t) => t.projectId.equals(projectId) & t.status.equals('running') & t.endedAt.isNull() & t.runningSince.isNull())..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).getSingleOrNull();

  // Contributions
  Future<int> insertContribution(ContributionsCompanion contribution) => into(contributions).insert(contribution);
  Future<bool> updateContribution(ContributionsCompanion contribution) => update(contributions).replace(contribution);
  Future<int> deleteContribution(int id) => (contributions.delete()..where((t) => t.id.equals(id))).go();
  Future<List<Contribution>> getContributionsForSession(int sessionId) => (select(contributions)..where((t) => t.sessionId.equals(sessionId))).get();
  Future<List<Contribution>> getContributionsForProject(int projectId) {
    return customSelect(
      'SELECT c.* FROM contributions c JOIN sessions s ON c.session_id = s.id WHERE s.project_id = ? ORDER BY c.created_at DESC',
      variables: [Variable.withInt(projectId)],
      readsFrom: {contributions, sessions},
    ).map((row) => Contribution(
      id: row.read<int>('id'),
      sessionId: row.read<int>('session_id'),
      title: row.read<String>('title'),
      type: row.read<String?>('type'),
      createdAt: row.read<DateTime>('created_at'),
    )).get();
  }

  // Notes
  Future<int> insertNote(NotesCompanion note) => into(notes).insert(note);
  Future<bool> updateNote(NotesCompanion note) => update(notes).replace(note);
  Future<int> deleteNote(int id) => (notes.delete()..where((t) => t.id.equals(id))).go();
  Future<List<Note>> getNotesForProject(int projectId) => (select(notes)..where((t) => t.projectId.equals(projectId))..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();

  // Settings
  Future<void> setSetting(String key, String value) => into(settingsTable).insertOnConflictUpdate(SettingsTableCompanion(key: Value(key), value: Value(value)));
  Future<String?> getSetting(String key) => (select(settingsTable)..where((t) => t.key.equals(key))).map((row) => row.value).getSingleOrNull();
}

LazyDatabase _openConnection({String? path}) {
  return LazyDatabase(() async {
    final file = path != null
        ? File(path)
        : File(p.join((await getApplicationDocumentsDirectory()).path, 'chromodoro.db'));
    return NativeDatabase.createInBackground(file);
  });
}