import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import '../repositories/settings_repository.dart';

/// Remembers the full-window geometry and the mini widget position across app
/// restarts, mirroring the Python version's `window_geometry` /
/// `mini_position` persistence.
class WindowPrefs {
  final SettingsRepository _settings;

  WindowPrefs(this._settings);

  Future<void> saveCurrentGeometry() async {
    try {
      final size = await windowManager.getSize();
      final pos = await windowManager.getPosition();
      await _settings.set(
        'window_geometry',
        '${size.width.round()}x${size.height.round()}+${pos.dx.round()}+${pos.dy.round()}',
      );
    } catch (_) {
      // Best-effort.
    }
  }

  Future<Offset?> restoreSavedMiniPosition() async {
    try {
      return parseOffset(await _settings.get('mini_position'));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMiniPosition(Offset position) async {
    try {
      await _settings.set(
        'mini_position',
        '${position.dx.round()},${position.dy.round()}',
      );
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> restoreSavedGeometry() async {
    try {
      final raw = await _settings.get('window_geometry');
      final geo = parseGeometry(raw);
      if (geo != null) {
        await windowManager.setSize(geo.$1);
        await windowManager.setPosition(geo.$2);
      }
    } catch (_) {
      // Best-effort.
    }
  }

  /// Parses "WxH+X+Y" into (size, position), null if malformed.
  static (Size, Offset)? parseGeometry(String? raw) {
    if (raw == null) return null;
    final plus = raw.split('+');
    if (plus.length != 3) return null;
    final dims = plus[0].split('x');
    if (dims.length != 2) return null;
    final w = int.tryParse(dims[0]);
    final h = int.tryParse(dims[1]);
    final x = int.tryParse(plus[1]);
    final y = int.tryParse(plus[2]);
    if (w == null || h == null || x == null || y == null) return null;
    return (Size(w.toDouble(), h.toDouble()), Offset(x.toDouble(), y.toDouble()));
  }

  /// Parses "x,y" into an Offset, null if malformed.
  static Offset? parseOffset(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final x = int.tryParse(parts[0].trim());
    final y = int.tryParse(parts[1].trim());
    if (x == null || y == null) return null;
    return Offset(x.toDouble(), y.toDouble());
  }
}