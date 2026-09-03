class Note {
  final int? id;
  final int projectId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    this.id,
    required this.projectId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Note copyWith({
    int? id,
    int? projectId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          projectId == other.projectId &&
          content == other.content &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => id.hashCode ^ projectId.hashCode ^ content.hashCode ^ createdAt.hashCode ^ updatedAt.hashCode;
}
