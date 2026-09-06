import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart' as db;
import '../../models/project.dart' as models;
import '../../providers/app_providers.dart';
import '../../services/timer_service.dart';
import '../../utils/formatting.dart';

/// Full-screen focus timer for a project.
///
/// Mirrors the Python timer_view: standby, running, paused, break, review.
class TimerScreen extends ConsumerStatefulWidget {
  final int projectId;
  final bool startNow;

  const TimerScreen({super.key, required this.projectId, this.startNow = false});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  TimerService? _timer;

  @override
  void initState() {
    super.initState();
    _timer = ref.read(timerServiceProvider);
    if (widget.startNow) {
      // Switch semantics: park the current session (if any) and resume a
      // parked session for this project, or start fresh if none exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _timer!.switchTo(widget.projectId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = _timer!;
    final timerAsync = ref.watch(projectsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: const Text('Focus'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.character == null) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  if (!timer.hasFinished) {
                    if (timer.isRunning) {
                      timer.pause();
                    } else if (timer.state == TimerState.paused) {
                      timer.resume();
                    }
                  }
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.pop(context);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: ListenableBuilder(
              listenable: timer,
              builder: (context, _) {
                return _renderBody(timer, timerAsync);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderBody(TimerService timer, AsyncValue<List<models.Project>> projectsAsync) {
    final allProjects = projectsAsync.value ?? [];
    // Determine project name, preferring the project being viewed so the title
    // always matches whatever project this screen belongs to.
    String projectName = 'Project';
    models.Project? viewed;
    for (final p in allProjects) {
      if (p.id == widget.projectId) {
        viewed = p;
        break;
      }
    }
    if (viewed != null) {
      projectName = viewed.name;
    } else if (timer.lastProjectId != null) {
      for (final p in allProjects) {
        if (p.id == timer.lastProjectId) {
          projectName = p.name;
          break;
        }
      }
    }

    // Review state (finished focus session for THIS project).
    final finished = timer.finished;
    if (timer.hasFinished && finished != null && finished.projectId == widget.projectId) {
      return _buildReview(timer, projectName);
    }

    // Standby: another project's session is active in the timer. Offer to switch.
    if (timer.isActive && timer.activeProjectId != widget.projectId) {
      return _buildStandby(timer, projectName, allProjects);
    }

    final isBreak = timer.mode != TimerMode.focus;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(projectName.toUpperCase(),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (isBreak)
          _statusLabel(timer.isLongBreak ? 'LONG BREAK' : 'BREAK',
              timer.isLongBreak ? 0xFFBA68C8 : 0xFF64B5F6)
        else
          _statusLabel(
              timer.state == TimerState.running
                  ? 'FOCUS'
                  : timer.state == TimerState.paused
                      ? 'PAUSED'
                      : 'READY',
              timer.state == TimerState.paused
                  ? 0xFFFFB74D
                  : timer.state == TimerState.running
                      ? 0xFF66BB6A
                      : 0xFF66BB6A),
        const SizedBox(height: 8),
        _cycleLine(timer),
        const SizedBox(height: 8),
        Text(timer.formattedTime,
            style: const TextStyle(
                fontSize: 72, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono')),
        const SizedBox(height: 16),
        SizedBox(
          width: 420,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: timer.progress,
              minHeight: 12,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildActions(timer, allProjects),
        const SizedBox(height: 32),
        _ActiveSessionsPanel(allProjects: allProjects, currentProjectId: widget.projectId),
        const SizedBox(height: 24),
        Text('Space: pause / resume   ·   Esc: back',
            style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _statusLabel(String text, int color) {
    return Text(text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: Color(color)));
  }

  /// Standby view shown when this project is not the currently active one.
  /// The user can switch the timer to this project via a single button.
  Widget _buildStandby(TimerService timer, String projectName, List<models.Project> allProjects) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz,
              size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('ANOTHER SESSION IS RUNNING',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('The timer is currently on another project.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              timer.switchTo(widget.projectId);
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => TimerScreen(projectId: widget.projectId)));
            },
            icon: const Icon(Icons.swap_horiz),
            label: Text('Switch to $projectName'),
          ),
          const SizedBox(height: 32),
          _ActiveSessionsPanel(allProjects: allProjects, currentProjectId: widget.projectId),
        ],
      ),
    );
  }

  Widget _cycleLine(TimerService timer) {
    final cycles = timer.completedCycles;
    final total = 4;
    if (cycles >= total) {
      return Text('Long break after this cycle',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12));
    }
    return Text('Cycle ${cycles + 1} of $total',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12));
  }

  Widget _buildActions(TimerService timer, List<models.Project> allProjects) {
    final isBreak = timer.mode != TimerMode.focus;
    if (isBreak) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timer.state == TimerState.running)
            FilledButton(onPressed: timer.pause, child: const Text('Pause'))
          else if (timer.state == TimerState.paused)
            FilledButton(onPressed: timer.resume, child: const Text('Resume')),
          if (timer.isRunning || timer.state == TimerState.paused) ...[
            const SizedBox(width: 12),
            OutlinedButton(onPressed: timer.skipBreak, child: const Text('Skip break')),
          ] else
            OutlinedButton(onPressed: timer.skipBreak, child: const Text('Skip break')),
          const SizedBox(width: 12),
          _miniWidgetButton(),
        ],
      );
    }
    if (timer.state == TimerState.running) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(onPressed: timer.pause, child: const Text('Pause')),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () => _onEndSession(timer), child: const Text('End session')),
          const SizedBox(width: 12),
          _SwitchMenuButton(timer: timer, currentProjectId: widget.projectId, allProjects: allProjects),
          const SizedBox(width: 12),
          _miniWidgetButton(),
        ],
      );
    }
    if (timer.state == TimerState.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(onPressed: timer.resume, child: const Text('Resume')),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () => _onEndSession(timer), child: const Text('End session')),
          const SizedBox(width: 12),
          _SwitchMenuButton(timer: timer, currentProjectId: widget.projectId, allProjects: allProjects),
          const SizedBox(width: 12),
          _miniWidgetButton(),
        ],
      );
    }
    // Idle (no session running for anyone). If this project has a parked
    // session, offer to resume it instead of blindly starting fresh.
    return _IdleActions(timer: timer, projectId: widget.projectId);
  }

  Widget _miniWidgetButton() {
    return OutlinedButton(
      onPressed: () => ref.read(miniModeProvider.notifier).toggle(),
      child: const Text('Widget'),
    );
  }

  Future<void> _onEndSession(TimerService timer) async {
    // Freeze the clock now so the decision dialog's open-time isn't counted.
    timer.pause();
    final elapsedSeconds = timer.currentFocusSeconds.round();
    final elapsed = formatDuration(elapsedSeconds);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session interrupted'),
        content: Text('Time focused so far: $elapsed\n\nWhat do you want to do with this time?'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx, 'register'),
              child: Text('Register $elapsed')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'continue'), child: const Text('Keep going')),
        ],
      ),
    );
    if (mounted) {
      if (choice == 'register') {
        await timer.registerInterrupted();
      } else if (choice == 'discard') {
        await timer.discard();
      } else if (choice == 'continue') {
        timer.resume();
      }
    }
  }

  Widget _buildReview(TimerService timer, String projectName) {
    final finished = timer.finished;
    final durationText = formatDuration((finished?.duration ?? 0).round());
    final todayText = '';

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          Text('Pomodoro complete  ·  +$durationText logged',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Time added to $projectName$todayText. What did you produce?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _ReviewForm(timer: timer),
        ],
      ),
    );
  }
}

/// Idle/focus actions shown when no session is running for any project. If this
/// project has a parked session, offer to resume it instead of starting fresh.
class _IdleActions extends ConsumerStatefulWidget {
  final TimerService timer;
  final int projectId;

  const _IdleActions({required this.timer, required this.projectId});

  @override
  ConsumerState<_IdleActions> createState() => _IdleActionsState();
}

class _IdleActionsState extends ConsumerState<_IdleActions> {
  db.Session? _parked;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(sessionRepositoryProvider);
    final parked = await repo.getParked(widget.projectId);
    if (!mounted) return;
    setState(() {
      _parked = parked;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    if (!_loaded) return const SizedBox.shrink();
    final hasParked = _parked != null && _parked!.duration != null && _parked!.duration! > 0;

    if (hasParked) {
      final durText = formatDuration(_parked!.duration!.round());
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => timer.resumeParked(widget.projectId),
            icon: const Icon(Icons.play_arrow),
            label: Text('Resume  ·  $durText paused'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => timer.startFocus(widget.projectId),
            child: const Text('Start a new focus instead'),
          ),
        ],
      );
    }

    return FilledButton(
      onPressed: () => timer.startFocus(widget.projectId),
      child: const Text('Start focus'),
    );
  }
}

/// Lists every project that currently has an active (running/paused) session or
/// a parked session, with its elapsed / paused time, on the focus screen.
class _ActiveSessionsPanel extends ConsumerWidget {
  final List<models.Project> allProjects;
  final int currentProjectId;

  const _ActiveSessionsPanel({required this.allProjects, required this.currentProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionRepo = ref.watch(sessionRepositoryProvider);
    final activeTimer = ref.watch(timerServiceProvider);

    final future = () async {
      final entries = <_SessionEntry>[];
      for (final p in allProjects) {
        final id = p.id;
        if (id == null) continue;
        final running = await sessionRepo.getLatestRunning(id);
        final parked = await sessionRepo.getParked(id);
        if (running != null) {
          entries.add(_SessionEntry(p, running.duration, paused: false, activeNow: true));
        } else if (parked != null && parked.duration != null && parked.duration! > 0) {
          entries.add(_SessionEntry(p, parked.duration, paused: true, activeNow: false));
        }
      }
      return entries;
    }();

    return FutureBuilder<List<_SessionEntry>>(
      future: future,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const [];
        if (entries.isEmpty) return const SizedBox.shrink();
        return Container(
          width: 520,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active sessions',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              ...entries.map((e) {
                final isThis = e.project.id == currentProjectId;
                final isRunningNow = e.project.id == activeTimer.activeProjectId &&
                    activeTimer.isRunning &&
                    !e.paused;
                final color = e.paused
                    ? const Color(0xFFFFB74D)
                    : isRunningNow
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFF66BB6A);
                final timeText = formatDuration((e.duration ?? 0).round());
                return MouseRegion(
                  cursor: isThis ? SystemMouseCursors.basic : SystemMouseCursors.click,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: isThis
                        ? null
                        : () {
                            activeTimer.switchTo(e.project.id!);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => TimerScreen(projectId: e.project.id!)),
                            );
                          },
                    hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(e.paused ? Icons.pause_circle : Icons.play_circle, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.project.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isThis)
                            const Text('· this project  ',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            '${e.paused ? 'paused ' : ''}$timeText',
                            style: TextStyle(
                                fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          if (!isThis) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.swap_horiz,
                                size: 16, color: Theme.of(context).colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _SessionEntry {
  final models.Project project;
  final double? duration;
  final bool paused;
  final bool activeNow;
  _SessionEntry(this.project, this.duration, {required this.paused, required this.activeNow});
}

class _ReviewForm extends ConsumerStatefulWidget {
  final TimerService timer;

  const _ReviewForm({required this.timer});

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  final _controller = TextEditingController();
  String _feedback = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    final finished = widget.timer.finished;
    if (title.isEmpty || finished == null) {
      setState(() => _feedback = 'Write something first, or take a break.');
      return;
    }
    await ref.read(sessionRepositoryProvider).addContribution(
          sessionId: finished.id,
          title: title,
        );
    _controller.clear();
    setState(() => _feedback = 'Added. ($title)');
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    return Column(
      children: [
        SizedBox(
          width: 480,
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _add(),
            decoration: const InputDecoration(
              hintText: 'e.g. Implemented map loading',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(_feedback,
            style: TextStyle(fontSize: 12,
                color: _feedback.startsWith('Added') ? Colors.green : Colors.grey)),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(onPressed: _add, child: const Text('Add contribution')),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: timer.startBreak, child: const Text('Take a break')),
            const SizedBox(width: 12),
            TextButton(onPressed: timer.skipBreak, child: const Text('Skip break')),
          ],
        ),
      ],
    );
  }
}

/// A popup menu button to switch to another project with a parked session.
class _SwitchMenuButton extends ConsumerWidget {
  final TimerService timer;
  final int currentProjectId;
  final List<models.Project> allProjects;

  const _SwitchMenuButton({required this.timer, required this.currentProjectId, required this.allProjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionRepo = ref.watch(sessionRepositoryProvider);
    final otherProjects = allProjects
        .where((p) => p.id != null && p.id != currentProjectId)
        .toList();

    if (otherProjects.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      icon: const Icon(Icons.swap_horiz),
      tooltip: 'Switch project',
      onSelected: (projectId) {
        timer.switchTo(projectId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TimerScreen(projectId: projectId)),
        );
      },
      itemBuilder: (context) => otherProjects.map((p) {
        return PopupMenuItem<int>(
          value: p.id!,
          child: FutureBuilder<db.Session?>(
            future: sessionRepo.getParked(p.id!),
            builder: (context, snapshot) {
              final parked = snapshot.data;
              final hasParked = parked != null && parked.duration != null && parked.duration! > 0;
              final parkedText = hasParked
                  ? ' · ${formatDuration(parked.duration!.round())} parked'
                  : '';
              return Row(
                children: [
                  Icon(Icons.swap_horiz, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('${p.name}$parkedText'),
                ],
              );
            },
          ),
        );
      }).toList(),
    );
  }
}
