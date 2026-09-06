import 'package:drift/drift.dart';
import '../database/app_database.dart' as db;
import '../models/note.dart' as models;

class NoteRepository {
  final db.AppDatabase _db;

  NoteRepository(this._db);

  Future<int> create({
    required int projectId,
    required String content,
  }) {
    return _db.into(_db.notes).insert(
      db.NotesCompanion(
        projectId: Value(projectId),
        content: Value(content),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> update({
    required int id,
    required String content,
  }) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id)))
        .write(
      db.NotesCompanion(
        content: Value(content),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> delete(int id) {
    return (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  Future<List<models.Note>> getForProject(int projectId) async {
    final dbNotes = await (_db.select(_db.notes)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return dbNotes.map(_toModel).toList();
  }

  Stream<List<models.Note>> watchForProject(int projectId) {
    return (_db.select(_db.notes)
          ..where((t) => t.projectId.equals(projectId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch()
        .map((notes) => notes.map(_toModel).toList());
  }

  /// Emits whenever the notes table changes, to invalidate caches.
  Stream<int> watchNoteActivityStamp() {
    return (_db.select(_db.notes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .watch()
        .map((rows) => rows.isEmpty ? 0 : rows.first.id);
  }

  models.Note _toModel(db.Note n) {
    return models.Note(
      id: n.id,
      projectId: n.projectId,
      content: n.content,
      createdAt: n.createdAt,
      updatedAt: n.updatedAt,
    );
  }
}