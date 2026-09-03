class AppSettings {
  final int workMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int cyclesBeforeLongBreak;
  final bool soundAlerts;
  final bool autoStartAfterBreak;
  final bool closeToTray;
  final bool startInTray;
  final bool startFilterCurrentDay;

  const AppSettings({
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.longBreakMinutes = 15,
    this.cyclesBeforeLongBreak = 4,
    this.soundAlerts = true,
    this.autoStartAfterBreak = false,
    this.closeToTray = true,
    this.startInTray = false,
    this.startFilterCurrentDay = false,
  });

  AppSettings copyWith({
    int? workMinutes,
    int? breakMinutes,
    int? longBreakMinutes,
    int? cyclesBeforeLongBreak,
    bool? soundAlerts,
    bool? autoStartAfterBreak,
    bool? closeToTray,
    bool? startInTray,
    bool? startFilterCurrentDay,
  }) {
    return AppSettings(
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      cyclesBeforeLongBreak: cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak,
      soundAlerts: soundAlerts ?? this.soundAlerts,
      autoStartAfterBreak: autoStartAfterBreak ?? this.autoStartAfterBreak,
      closeToTray: closeToTray ?? this.closeToTray,
      startInTray: startInTray ?? this.startInTray,
      startFilterCurrentDay: startFilterCurrentDay ?? this.startFilterCurrentDay,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          workMinutes == other.workMinutes &&
          breakMinutes == other.breakMinutes &&
          longBreakMinutes == other.longBreakMinutes &&
          cyclesBeforeLongBreak == other.cyclesBeforeLongBreak &&
          soundAlerts == other.soundAlerts &&
          autoStartAfterBreak == other.autoStartAfterBreak &&
          closeToTray == other.closeToTray &&
          startInTray == other.startInTray &&
          startFilterCurrentDay == other.startFilterCurrentDay;

  @override
  int get hashCode =>
      workMinutes.hashCode ^
      breakMinutes.hashCode ^
      longBreakMinutes.hashCode ^
      cyclesBeforeLongBreak.hashCode ^
      soundAlerts.hashCode ^
      autoStartAfterBreak.hashCode ^
      closeToTray.hashCode ^
      startInTray.hashCode ^
      startFilterCurrentDay.hashCode;
}