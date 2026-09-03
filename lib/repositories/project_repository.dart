import 'package:drift/drift.dart';
import '../database/app_database.dart' as db;
import '../models/project.dart' as models;

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

  Future<bool> update({
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
      id: Value(id),
      name: name != null ? Value(name) : const Value.absent(),
      description: description != null ? Value(description) : const Value.absent(),
      dailyGoalMinutes: dailyGoalMinutes != null ? Value(dailyGoalMinutes) : const Value.absent(),
      weeklyGoalMinutes: weeklyGoalMinutes != null ? Value(weeklyGoalMinutes) : const Value.absent(),
      monthlyGoalMinutes: monthlyGoalMinutes != null ? Value(monthlyGoalMinutes) : const Value.absent(),
      goalDaysOfWeek: goalDaysOfWeek != null ? Value(goalDaysOfWeek.join(',')) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
    );
    return _db.update(_db.projects).replace(companion);
  }

  Future<bool> archive(int id) {
    return _db.update(_db.projects).replace(
      db.ProjectsCompanion(id: Value(id), status: const Value('archived')),
    );
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
      "SELECT project_id, SUM(duration) as total FROM sessions WHERE status = 'completed' GROUP BY project_id",
      readsFrom: {_db.sessions},
    ).get();
    return {for (var row in rows) row.read<int>('project_id'): row.read<double>('total').toInt()};
  }

  Future<Map<int, int>> getSessionCountPerProject() async {
    final rows = await _db.customSelect(
      "SELECT project_id, COUNT(*) as count FROM sessions WHERE status = 'completed' GROUP BY project_id",
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
      "SELECT project_id, SUM(duration) as total FROM sessions WHERE status = 'completed' AND started_at >= ? GROUP BY project_id",
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