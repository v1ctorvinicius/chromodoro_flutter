import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Manages the system tray icon and its context menu.
///
/// The icon/menu are created once via [init]. The action callbacks are wired by
/// the app (they need access to the timer and window services), and can be
/// updated at any time via the setters below.
class TrayService with TrayListener {
  static const String _iconAsset = 'assets/images/tray_icon.ico';

  /// Called when the user clicks the tray icon (show/hide the window).
  void Function()? onToggleWindow;

  /// Called by the "Iniciar/Pausar" menu item (toggle the running state).
  void Function()? onToggleTimer;

  /// Called by the "Completar fase" menu item.
  void Function()? onCompletePhase;

  /// Called by the "Modo mini (domino)" menu item.
  void Function()? onToggleMini;

  /// Called by the "Sair" menu item.
  void Function()? onQuit;

  /// Returns the tooltip text (optionally reflects the timer status).
  String Function()? tooltipBuilder;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await trayManager.setIcon(_iconAsset);
      await trayManager.setToolTip(tooltipBuilder?.call() ?? 'Chromodoro');
      await trayManager.setContextMenu(_buildMenu());
      trayManager.addListener(this);
    } catch (e) {
      debugPrint('TrayService.init failed: $e');
    }
    _initialized = true;
  }

  Menu _buildMenu() {
    return Menu(
      items: [
        MenuItem(
          key: 'toggle',
          label: 'Mostrar / Ocultar',
          onClick: (_) => onToggleWindow?.call(),
        ),
        MenuItem(
          key: 'timer',
          label: 'Iniciar / Pausar',
          onClick: (_) => onToggleTimer?.call(),
        ),
        MenuItem(
          key: 'complete',
          label: 'Completar fase',
          onClick: (_) => onCompletePhase?.call(),
        ),
        MenuItem(
          key: 'mini',
          label: 'Modo mini (dominó)',
          onClick: (_) => onToggleMini?.call(),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'Sair',
          onClick: (_) => onQuit?.call(),
        ),
      ],
    );
  }

  /// Updates the hover tooltip (e.g. when the timer status changes).
  Future<void> updateTooltip(String text) async {
    try {
      await trayManager.setToolTip(text);
    } on Object {
      // Best-effort.
    }
  }

  @override
  void onTrayIconMouseDown() {
    onToggleWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } on Object {
      // Best-effort.
    }
  }
}

/// Action helpers that operate on the window (used by the tray wiring).
Future<void> showAppWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

Future<void> hideAppWindow() async {
  await windowManager.hide();
}

Future<void> toggleAppWindow() async {
  if (await windowManager.isVisible()) {
    await hideAppWindow();
  } else {
    await showAppWindow();
  }
}

Future<void> quitApp() async {
  try {
    await windowManager.destroy();
  } on Object {
    // Best-effort.
  }
  exit(0);
}
