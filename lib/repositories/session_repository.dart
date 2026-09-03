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

  Future<bool> complete({
    required int id,
    required double duration,
  }) {
    return endSession(id: id, duration: duration, status: 'completed');
  }

  Future<bool> endSession({
    required int id,
    required double duration,
    required String status,
  }) {
    return _db.update(_db.sessions).replace(
      SessionsCompanion(
        id: Value(id),
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

  Future<bool> pause({
    required int id,
  }) {
    return _db.update(_db.sessions).replace(
      SessionsCompanion(
        id: Value(id),
        status: const Value('paused'),
        runningSince: const Value.absent(),
      ),
    );
  }

  Future<bool> resume({
    required int id,
  }) {
    return _db.update(_db.sessions).replace(
      SessionsCompanion(
        id: Value(id),
        status: const Value('running'),
        runningSince: Value(DateTime.now()),
      ),
    );
  }

  Future<Session?> getRunning() {
    return (_db.select(_db.sessions)
          ..where((t) => t.status.equals('running'))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .getSingleOrNull();
  }

  Future<Session?> getParked(int projectId) {
    return (_db.select(_db.sessions)
          ..where((t) => t.projectId.equals(projectId) & t.status.equals('running') & t.endedAt.isNull() & t.runningSince.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .getSingleOrNull();
  }

  Future<List<Session>> getForProject(int projectId) {
    return (_db.select(_db.sessions)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
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

  Future<bool> updateContribution({
    required int id,
    required String title,
  }) {
    return _db.update(_db.contributions).replace(
      ContributionsCompanion(id: Value(id), title: Value(title)),
    );
  }

  Future<int> deleteContribution(int id) {
    return (_db.delete(_db.contributions)..where((t) => t.id.equals(id))).go();
  }
}