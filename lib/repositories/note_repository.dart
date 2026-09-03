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

  Future<bool> update({
    required int id,
    required String content,
  }) {
    return _db.update(_db.notes).replace(
      db.NotesCompanion(
        id: Value(id),
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