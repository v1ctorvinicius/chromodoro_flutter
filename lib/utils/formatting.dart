import 'package:intl/intl.dart';

String formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  if (minutes < 60) {
    return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
  }
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
}

/// Compact duration like the Python `format_duration` used in the dashboard
/// footer: "0 min", "12 min", "2h 5m", "2h".
String formatDurationShort(int seconds) {
  if (seconds < 60) return '0 min';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours == 0) return '$minutes min';
  if (minutes > 0) return '${hours}h ${minutes}m';
  return '${hours}h';
}

String formatDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) {
    return DateFormat('EEEE').format(date);
  }
  return DateFormat('MMM d').format(date);
}

String formatShortDayLabel(int weekday) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (weekday >= 0 && weekday < 7) return days[weekday];
  return '';
}

List<int> parseGoalDays(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  return raw.split(',').map((e) => int.tryParse(e.trim()) ?? -1).where((e) => e >= 0 && e < 7).toList();
}

String serializeGoalDays(List<int> days) {
  return days.join(',');
}

bool isGoalDay(List<int> days, int weekday) {
  if (days.isEmpty) return true;
  return days.contains(weekday);
}