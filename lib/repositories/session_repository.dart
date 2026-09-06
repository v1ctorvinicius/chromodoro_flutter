import 'package:drift/drift.dart';
import '../database/app_database.dart';

class SessionRepository {
  final AppDatabase _db;

  SessionRepository(this._db);

  Future<int> start({
    required int projectId,
  }) {
    return _db.into(_db.sessions).insert(
      SessionsCompanion(
        projectId: Value(projectId),
        startedAt: Value(DateTime.now()),
        status: const Value('running'),
        runningSince: Value(DateTime.now()),
      ),
    );
  }

  Future<int> complete({
    required int id,
    required double duration,
  }) {
    return endSession(id: id, duration: duration, status: 'completed');
  }

  Future<int> endSession({
    required int id,
    required double duration,
    required String status,
  }) {
    return (_db.update(_db.sessions)..where((t) => t.id.equals(id)))
        .write(
      SessionsCompanion(
        duration: Value(duration),
        status: Value(status),
        endedAt: Value(DateTime.now()),
        runningSince: const Value.absent(),
      ),
    );
  }

  Future<int> delete(int id) {
    return (_db.delete(_db.sessions)..where((t) => t.id.equals(id))).go();
  }

  Future<Session?> getById(int id) {
    return (_db.select(_db.sessions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> pause({
    required int id,
  }) {
    return (_db.update(_db.sessions)..where((t) => t.id.equals(id)))
        .write(
      SessionsCompanion(
        status: const Value('paused'),
        runningSince: const Value(null),
      ),
    );
  }

  Future<int> resume({
    required int id,
  }) {
    return (_db.update(_db.sessions)..where((t) => t.id.equals(id)))
        .write(
      SessionsCompanion(
        status: const Value('running'),
        runningSince: Value(DateTime.now()),
      ),
    );
  }

  Future<Session?> getRunning() async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) => t.status.equals('running'))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// The most recent actively-running (non-parked, runningSince not null)
  /// session for [projectId], if any.
  Future<Session?> getLatestRunning(int projectId) async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) => t.projectId.equals(projectId) &
              t.status.equals('running') &
              t.runningSince.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<Session?> getParked(int projectId) async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) => t.projectId.equals(projectId) & t.status.equals('running') & t.endedAt.isNull() & t.runningSince.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Closes out any leftover active/parked sessions for [projectId] (status
  /// 'running' and no endedAt), optionally keeping [exceptId]. Used to guarantee
  /// only a single active session per project, preventing the duplicate-parked
  /// state that made [getParked]/[getLatestRunning] throw.
  Future<void> endIncompleteForProject(int projectId, {int? exceptId}) async {
    final update = _db.update(_db.sessions)..where((t) {
      var exp = t.projectId.equals(projectId) &
          t.status.equals('running') &
          t.endedAt.isNull();
      if (exceptId != null) exp = exp & t.id.equals(exceptId).not();
      return exp;
    });
    await update.write(
      SessionsCompanion(
        status: const Value('interrupted'),
        endedAt: Value(DateTime.now()),
        runningSince: const Value(null),
      ),
    );
  }

  /// Parks the session: saves its elapsed duration but stops its running clock
  /// (sets runningSince to NULL) while keeping status='running' and endedAt NULL.
  /// A parked session can later be resumed with [resume] or adopted via switch.
  Future<int> park({
    required int id,
    required double duration,
  }) {
    return (_db.update(_db.sessions)..where((t) => t.id.equals(id)))
        .write(
      SessionsCompanion(
        duration: Value(duration),
        status: const Value('running'),
        runningSince: const Value(null),
      ),
    );
  }

  /// The most recently parked session across all projects, if any.
  Future<Session?> getLatestParked() async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) => t.status.equals('running') & t.endedAt.isNull() & t.runningSince.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// All parked sessions (status 'running', endedAt NULL, runningSince NULL),
  /// one per project. Consumers should only rely on the latest per project.
  Future<List<Session>> getAllParked() {
    return (_db.select(_db.sessions)
          ..where((t) => t.status.equals('running') & t.endedAt.isNull() & t.runningSince.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  /// True if the given project has a session that is actively running right
  /// now (runningSince not NULL).
  Future<bool> hasActiveRunning() async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) => t.status.equals('running') & t.runningSince.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    return rows.isNotEmpty;
  }

  Future<List<Session>> getForProject(int projectId) {
    return (_db.select(_db.sessions)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  /// Emits whenever the sessions table changes (insert/update/delete). Used to
  /// invalidate cached summaries so counts/history refresh automatically.
  Stream<int> watchSessionActivityStamp() {
    return (_db.select(_db.sessions)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .watch()
        .map((rows) => rows.isEmpty ? 0 : rows.first.id);
  }

  /// Emits whenever the contributions table changes.
  Stream<int> watchContributionActivityStamp() {
    return (_db.select(_db.contributions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .watch()
        .map((rows) => rows.isEmpty ? 0 : rows.first.id);
  }

  Stream<List<Session>> watchForProject(int projectId) {
    return (_db.select(_db.sessions)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  Future<int> addContribution({
    required int sessionId,
    required String title,
    String? type,
  }) {
    return _db.into(_db.contributions).insert(
      ContributionsCompanion(
        sessionId: Value(sessionId),
        title: Value(title),
        type: Value(type),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Contribution>> getContributionsForSession(int sessionId) {
    return (_db.select(_db.contributions)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
  }

  Future<List<Contribution>> getContributionsForProject(int projectId) {
    return _db.customSelect(
      'SELECT c.* FROM contributions c JOIN sessions s ON c.session_id = s.id WHERE s.project_id = ? ORDER BY c.created_at DESC',
      variables: [Variable.withInt(projectId)],
      readsFrom: {_db.contributions, _db.sessions},
    ).map((row) => Contribution(
      id: row.read<int>('id'),
      sessionId: row.read<int>('session_id'),
      title: row.read<String>('title'),
      type: row.read<String?>('type'),
      createdAt: row.read<DateTime>('created_at'),
    )).get();
  }

  Future<int> updateContribution({
    required int id,
    required String title,
  }) {
    return (_db.update(_db.contributions)..where((t) => t.id.equals(id)))
        .write(ContributionsCompanion(title: Value(title)));
  }

  Future<int> deleteContribution(int id) {
    return (_db.delete(_db.contributions)..where((t) => t.id.equals(id))).go();
  }
}