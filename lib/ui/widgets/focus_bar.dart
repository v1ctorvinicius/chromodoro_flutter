import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/project.dart' as models;
import '../../providers/app_providers.dart';
import '../../services/timer_service.dart';
import '../../utils/formatting.dart';
import '../screens/timer_screen.dart';

/// A compact status bar shown at the top of every screen while a session is
/// active. Displays the project name, remaining time, a progress bar, and
/// quick-action buttons. Color-coded: green = focus running, orange = focus paused,
/// purple = break running, blue = break paused, gray = idle / disabled.
class FocusBar extends ConsumerWidget {
  final VoidCallback? onOpenFocus;

  /// Toggles the mini "domino" widget mode.
  final VoidCallback? onToggleMini;

  const FocusBar({super.key, this.onOpenFocus, this.onToggleMini});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerServiceProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final parkedMap = ref.watch(parkedSessionsProvider).value ?? const <int, int>{};

    // Resolve project name.
    String projectName = '';
    final pid = timer.activeProjectId ?? timer.lastProjectId;
    if (pid != null) {
      for (final p in projectsAsync.value ?? []) {
        if (p.id == pid) {
          projectName = p.name;
          break;
        }
      }
    }

    final isRunning = timer.isRunning;
    final isPaused = timer.state == TimerState.paused;
    final isBreak = timer.mode != TimerMode.focus;
    final isActive = isRunning || isPaused;

    // Other projects that currently have a parked session (switch candidates).
    final activePid = timer.activeProjectId;
    final switchTargets = (projectsAsync.value ?? const <models.Project>[])
        .where((p) =>
            p.id != null && p.id != activePid && parkedMap.containsKey(p.id))
        .toList();

    // Color coding.
    final Color accent;
    final Color bg;
    final String statusText;
    if (isBreak) {
      if (isRunning) {
        accent = timer.isLongBreak ? const Color(0xFFBA68C8) : const Color(0xFF64B5F6);
        bg = accent.withValues(alpha: 0.12);
        statusText = timer.isLongBreak ? 'LONG BREAK' : 'BREAK';
      } else if (isPaused) {
        accent = timer.isLongBreak ? const Color(0xFFCE93D8) : const Color(0xFF90CAF9);
        bg = accent.withValues(alpha: 0.12);
        statusText = timer.isLongBreak ? 'LONG BREAK (PAUSED)' : 'BREAK (PAUSED)';
      } else {
        accent = Theme.of(context).colorScheme.onSurfaceVariant;
        bg = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
        statusText = 'IDLE';
      }
    } else {
      // Focus mode
      if (isRunning) {
        accent = const Color(0xFF66BB6A);
        bg = const Color(0xFF66BB6A).withValues(alpha: 0.12);
        statusText = 'FOCUS';
      } else if (isPaused) {
        accent = const Color(0xFFFFB74D);
        bg = const Color(0xFFFFB74D).withValues(alpha: 0.12);
        statusText = 'PAUSED';
      } else {
        accent = Theme.of(context).colorScheme.onSurfaceVariant;
        bg = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
        statusText = 'IDLE';
      }
    }

    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              // Project name
              if (projectName.isNotEmpty)
                Expanded(
                  child: Text(
                    projectName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      decoration: TextDecoration.none,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'No active session',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              // Status label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accent,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Timer
              Text(
                isActive ? timer.formattedTime : '--:--',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'RobotoMono',
                  color: isActive
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 10),
              // Progress bar
              if (isActive)
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: timer.progress,
                      minHeight: 5,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: accent,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              // Action buttons
              if (onOpenFocus != null)
                IconButton(
                  onPressed: onOpenFocus,
                  icon: const Icon(Icons.open_in_full, size: 18),
                  tooltip: 'Open focus screen',
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(36, 36),
                  ),
                ),
              if (isRunning)
                IconButton(
                  onPressed: timer.pause,
                  icon: const Icon(Icons.pause, size: 18),
                  tooltip: 'Pause',
                  style: IconButton.styleFrom(foregroundColor: accent, padding: EdgeInsets.zero, minimumSize: const Size(36, 36)),
                )
              else if (isPaused)
                IconButton(
                  onPressed: timer.resume,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  tooltip: 'Resume',
                  style: IconButton.styleFrom(foregroundColor: accent, padding: EdgeInsets.zero, minimumSize: const Size(36, 36)),
                ),
              if (isActive && switchTargets.isNotEmpty)
                PopupMenuButton<int>(
                  tooltip: 'Switch project',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onSelected: (projectId) {
                    timer.switchTo(projectId);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TimerScreen(projectId: projectId),
                      ),
                    );
                  },
                  itemBuilder: (context) => [
                    for (final p in switchTargets)
                      PopupMenuItem<int>(
                        value: p.id!,
                        child: Text(
                          '${p.name} · ${formatDuration(parkedMap[p.id] ?? 0)} parked',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  child: Icon(
                    Icons.swap_horiz,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (isActive)
                IconButton(
                  onPressed: () => _completePhase(context, timer),
                  icon: const Icon(Icons.skip_next, size: 18),
                  tooltip: 'Complete phase',
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(36, 36),
                  ),
                ),
              if (onToggleMini != null)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onToggleMini,
                  child: const Text('Widget'),
                ),
            ],
          ),
        );
      },
    );
  }

  void _completePhase(BuildContext context, TimerService timer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete phase?'),
        content: const Text('This will end the current phase early.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              timer.completePhase();
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}
