import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Size of the mini "domino" window (mirrors the Python version's 310x72).
const Size miniWindowSize = Size(300, 72);

/// Minimum window size used in normal (full) mode.
const Size fullWindowMinSize = Size(900, 600);

/// Size used when restoring from mini mode with nothing saved.
const Size fullWindowSize = Size(1200, 800);

Size? _savedFullSize;
Offset? _savedFullPosition;

/// The window's current top-left position.
Future<Offset> currentWindowPosition() => windowManager.getPosition();

/// Shrinks the main window into a tiny, borderless, always-on-top pill that
/// only shows the timer. Uses the same Flutter window (single engine instance).
/// The full-window geometry is captured so [exitMiniWindow] can restore it.
Future<void> enterMiniWindow({Offset? position}) async {
  _savedFullSize = await windowManager.getSize();
  _savedFullPosition = await windowManager.getPosition();

  await windowManager.setAsFrameless();
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
  await windowManager.setResizable(false);
  await windowManager.setAlwaysOnTop(true);
  await windowManager.setMinimumSize(miniWindowSize);
  await windowManager.setSize(miniWindowSize);
  if (position != null) {
    await windowManager.setPosition(position);
  }
  await windowManager.show();
  await windowManager.focus();
}

/// Restores the window to the normal framed, resizable, non-topmost state.
/// Restores the geometry captured when entering mini mode, falling back to the
/// standard size centered.
Future<void> exitMiniWindow() async {
  final size = _savedFullSize ?? fullWindowSize;
  final position = _savedFullPosition;

  await windowManager.setTitleBarStyle(TitleBarStyle.normal);
  await windowManager.setResizable(true);
  await windowManager.setAlwaysOnTop(false);
  await windowManager.setMinimumSize(fullWindowMinSize);
  await windowManager.setSize(size);
  if (position != null) {
    await windowManager.setPosition(position);
  } else {
    await windowManager.center();
  }
  await windowManager.show();
  await windowManager.focus();
}