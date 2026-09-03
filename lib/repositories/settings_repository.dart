import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  Future<void> set(String key, String value) {
    return _db.into(_db.settingsTable).insertOnConflictUpdate(
      SettingsTableCompanion(key: Value(key), value: Value(value)),
    );
  }

  Future<String?> get(String key) {
    return (_db.select(_db.settingsTable)..where((t) => t.key.equals(key)))
        .map((row) => row.value)
        .getSingleOrNull();
  }

  Future<AppSettings> load() async {
    return AppSettings(
      workMinutes: int.tryParse(await get('work_minutes') ?? '') ?? 25,
      breakMinutes: int.tryParse(await get('break_minutes') ?? '') ?? 5,
      longBreakMinutes: int.tryParse(await get('long_break_minutes') ?? '') ?? 15,
      cyclesBeforeLongBreak: int.tryParse(await get('cycles_before_long_break') ?? '') ?? 4,
      soundAlerts: (await get('sound_alerts')) != '0',
      autoStartAfterBreak: (await get('auto_start_after_break')) == '1',
      closeToTray: (await get('close_to_tray')) != '0',
      startInTray: (await get('start_in_tray')) == '1',
      startFilterCurrentDay: (await get('start_filter_current_day')) == '1',
    );
  }

  Future<void> save(AppSettings settings) async {
    await set('work_minutes', settings.workMinutes.toString());
    await set('break_minutes', settings.breakMinutes.toString());
    await set('long_break_minutes', settings.longBreakMinutes.toString());
    await set('cycles_before_long_break', settings.cyclesBeforeLongBreak.toString());
    await set('sound_alerts', settings.soundAlerts ? '1' : '0');
    await set('auto_start_after_break', settings.autoStartAfterBreak ? '1' : '0');
    await set('close_to_tray', settings.closeToTray ? '1' : '0');
    await set('start_in_tray', settings.startInTray ? '1' : '0');
    await set('start_filter_current_day', settings.startFilterCurrentDay ? '1' : '0');
  }
}