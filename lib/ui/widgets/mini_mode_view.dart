import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../models/project.dart' as models;
import '../../providers/app_providers.dart';
import '../../services/timer_service.dart';
import '../../services/window_service.dart';

/// The mini "domino" window: a tiny, borderless, always-on-top rectangular
/// pill (mirrors the Python version) showing a status dot, the remaining
/// time, the project name and action buttons. Draggable by clicking the
/// content area (no double-click behavior); the ✕ button restores the
/// full window.
class MiniModeView extends ConsumerWidget {
  const MiniModeView({super.key});

  static double get width => miniWindowSize.width;
  static double get height => miniWindowSize.height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerServiceProvider);
    final projects = ref.watch(projectsProvider).value ?? const <models.Project>[];

    final others = projects
        .where((p) => p.id != timer.activeProjectId)
        .toList();

    return Material(
      color: Colors.transparent,
      child: ListenableBuilder(
        listenable: timer,
        builder: (context, _) {
          final phase = _Phase.of(timer);
          final name = _projectName(projects, timer.activeProjectId);
          return Container(
            width: width,
            height: height,
            color: phase.background,
            child: Row(
              children: [
                // Draggable content area (left): dot + clock + project name.
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => windowManager.startDragging(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 0, 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: phase.dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timer.formattedTime,
                                style: const TextStyle(
                                  fontFamily: 'RobotoMono',
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E1E),
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: width - 120,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Action buttons (right).
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _miniButton(
                        onPressed: timer.isRunning ? timer.pause : timer.resume,
                        icon: timer.isRunning ? Icons.pause : Icons.play_arrow,
                      ),
                      if (others.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _miniButton(
                            onPressed: () {
                              ref.read(miniSwitchRequestedProvider.notifier).request();
                              ref.read(miniModeProvider.notifier).exit();
                            },
                            icon: Icons.swap_horiz,
                          ),
                        ),
                      _miniButton(
                        onPressed: () => ref.read(miniModeProvider.notifier).exit(),
                        icon: Icons.close,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniButton({
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x55000000), width: 1),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF444444)),
        ),
      ),
    );
  }

  String _projectName(List<models.Project> projects, int? id) {
    if (id == null) return 'No active session';
    for (final p in projects) {
      if (p.id == id) return p.name;
    }
    return 'No active session';
  }
}

class _Phase {
  final Color background;
  final Color dot;

  const _Phase(this.background, this.dot);

  static _Phase of(TimerService timer) {
    if (timer.mode != TimerMode.focus) {
      if (timer.isRunning) {
        return timer.isLongBreak
            ? const _Phase(Color(0xFFF3E5F5), Color(0xFFBA68C8))
            : const _Phase(Color(0xFFE3F2FD), Color(0xFF64B5F6));
      }
      return const _Phase(Color(0xFFE0E0E0), Color(0xFF9E9E9E));
    }
    if (timer.isRunning) {
      return const _Phase(Color(0xFFD7F2DA), Color(0xFF66BB6A));
    }
    if (timer.state == TimerState.paused) {
      return const _Phase(Color(0xFFFDEECA), Color(0xFFFFB74D));
    }
    return const _Phase(Color(0xFFEEEEEE), Color(0xFF9E9E9E));
  }
}