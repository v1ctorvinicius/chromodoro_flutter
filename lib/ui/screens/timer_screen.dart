import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _timer!.startFocus(widget.projectId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = _timer!;
    final timerAsync = ref.watch(projectsProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  if (!timer.hasFinished && timer.mode == TimerMode.focus) {
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
    // Determine project name
    String projectName = 'Project';
    if (timer.lastProjectId != null) {
      final list = projectsAsync.value ?? [];
      for (final p in list) {
        if (p.id == timer.lastProjectId) {
          projectName = p.name;
          break;
        }
      }
    } else {
      for (final p in (projectsAsync.value ?? [])) {
        if (p.id == widget.projectId) {
          projectName = p.name;
          break;
        }
      }
    }

    // Review state (finished focus session)
    if (timer.hasFinished) {
      return _buildReview(timer, projectName);
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
        _buildActions(timer),
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

  Widget _buildActions(TimerService timer) {
    final isBreak = timer.mode != TimerMode.focus;
    if (isBreak) {
      return OutlinedButton(
        onPressed: timer.skipBreak,
        child: const Text('Skip break'),
      );
    }
    if (timer.state == TimerState.running) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(onPressed: timer.pause, child: const Text('Pause')),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () => _onEndSession(timer), child: const Text('End session')),
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
        ],
      );
    }
    // standby
    return FilledButton(
      onPressed: () => timer.startFocus(widget.projectId),
      child: const Text('Start focus'),
    );
  }

  Future<void> _onEndSession(TimerService timer) async {
    final elapsed = formatDuration(timer.remainingSeconds > 0
        ? (timer.phaseTotalSeconds - timer.remainingSeconds)
        : timer.phaseTotalSeconds);
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
    if (choice == 'register') {
      await timer.registerInterrupted();
    } else if (choice == 'discard') {
      await timer.discard();
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
          ],
        ),
      ],
    );
  }
}
