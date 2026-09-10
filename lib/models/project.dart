class Project {
  final int? id;
  final String name;
  final String? description;
  final String status;
  final DateTime createdAt;
  final double dailyGoalMinutes;
  final double weeklyGoalMinutes;
  final double monthlyGoalMinutes;
  final String goalDaysOfWeek;
  final int color; // ARGB int (0 = auto-generate)

  const Project({
    this.id,
    required this.name,
    this.description,
    this.status = 'active',
    required this.createdAt,
    this.dailyGoalMinutes = 0,
    this.weeklyGoalMinutes = 0,
    this.monthlyGoalMinutes = 0,
    this.goalDaysOfWeek = '',
    this.color = 0,
  });

  Project copyWith({
    int? id,
    String? name,
    String? description,
    String? status,
    DateTime? createdAt,
    double? dailyGoalMinutes,
    double? weeklyGoalMinutes,
    double? monthlyGoalMinutes,
    String? goalDaysOfWeek,
    int? color,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
      monthlyGoalMinutes: monthlyGoalMinutes ?? this.monthlyGoalMinutes,
      goalDaysOfWeek: goalDaysOfWeek ?? this.goalDaysOfWeek,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          status == other.status &&
          createdAt == other.createdAt &&
          dailyGoalMinutes == other.dailyGoalMinutes &&
          weeklyGoalMinutes == other.weeklyGoalMinutes &&
          monthlyGoalMinutes == other.monthlyGoalMinutes &&
          goalDaysOfWeek == other.goalDaysOfWeek &&
          color == other.color;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ description.hashCode ^ status.hashCode ^ createdAt.hashCode ^ dailyGoalMinutes.hashCode ^ weeklyGoalMinutes.hashCode ^ monthlyGoalMinutes.hashCode ^ goalDaysOfWeek.hashCode ^ color.hashCode;
}

class Session {
  final int? id;
  final int projectId;
  final DateTime startedAt;
  final double? duration;
  final String status;
  final DateTime? endedAt;
  final DateTime? runningSince;

  const Session({
    this.id,
    required this.projectId,
    required this.startedAt,
    this.duration,
    this.status = 'running',
    this.endedAt,
    this.runningSince,
  });

  Session copyWith({
    int? id,
    int? projectId,
    DateTime? startedAt,
    double? duration,
    String? status,
    DateTime? endedAt,
    DateTime? runningSince,
  }) {
    return Session(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      startedAt: startedAt ?? this.startedAt,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      endedAt: endedAt ?? this.endedAt,
      runningSince: runningSince ?? this.runningSince,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          projectId == other.projectId &&
          startedAt == other.startedAt &&
          duration == other.duration &&
          status == other.status &&
          endedAt == other.endedAt &&
          runningSince == other.runningSince;

  @override
  int get hashCode => id.hashCode ^ projectId.hashCode ^ startedAt.hashCode ^ duration.hashCode ^ status.hashCode ^ endedAt.hashCode ^ runningSince.hashCode;
}

class Contribution {
  final int? id;
  final int sessionId;
  final String title;
  final String? type;
  final DateTime createdAt;

  const Contribution({
    this.id,
    required this.sessionId,
    required this.title,
    this.type,
    required this.createdAt,
  });

  Contribution copyWith({
    int? id,
    int? sessionId,
    String? title,
    String? type,
    DateTime? createdAt,
  }) {
    return Contribution(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      title: title ?? this.title,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contribution &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          sessionId == other.sessionId &&
          title == other.title &&
          type == other.type &&
          createdAt == other.createdAt;

  @override
  int get hashCode => id.hashCode ^ sessionId.hashCode ^ title.hashCode ^ type.hashCode ^ createdAt.hashCode;
}

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
