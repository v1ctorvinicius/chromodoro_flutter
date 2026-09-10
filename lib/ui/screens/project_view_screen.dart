import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart' as db;
import '../../models/project.dart' as models;
import '../../models/note.dart' as note_models;
import '../../providers/app_providers.dart';
import '../../services/timer_service.dart';
import '../../utils/formatting.dart';
import '../widgets/focus_bar.dart';
import '../widgets/project_form_dialog.dart';
import 'timer_screen.dart';

class ProjectViewScreen extends ConsumerStatefulWidget {
  final int projectId;

  const ProjectViewScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectViewScreen> createState() => _ProjectViewScreenState();
}

class _ProjectViewScreenState extends ConsumerState<ProjectViewScreen> {
  late Future<models.Project?> _projectFuture;

  @override
  void initState() {
    super.initState();
    _projectFuture = ref.read(projectRepositoryProvider).get(widget.projectId);
  }

  void _reload() {
    setState(() {
      _projectFuture = ref.read(projectRepositoryProvider).get(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<models.Project?>(
        future: _projectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final project = snapshot.data;
          if (project == null) {
            return const Center(child: Text('Project not found.'));
          }
          return _buildContent(project);
        },
      ),
    );
  }

  Widget _buildContent(models.Project project) {
    final theme = Theme.of(context);
    final timer = ref.watch(timerServiceProvider);
    final parkedMap = ref.watch(parkedSessionsProvider).value ?? const <int, int>{};
    final activeProjectId = timer.activeProjectId;
    final isActiveProject = activeProjectId == project.id;
    final isActiveAndRunning = isActiveProject && timer.isRunning;
    final isActiveAndPaused = isActiveProject && timer.state == TimerState.paused;
    final hasParked = parkedMap.containsKey(project.id) && activeProjectId != project.id;

    // Project color
    final projectColor = project.color != 0 ? Color(project.color) : _colorFromString(project.id?.toString() ?? '0');
    final statusColor = isActiveAndRunning
        ? const Color(0xFF66BB6A)
        : (isActiveAndPaused || hasParked)
            ? const Color(0xFFFFB74D)
            : theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      children: [
        FocusBar(
          onToggleMini: () => ref.read(miniModeProvider.notifier).toggle(),
          onOpenFocus: () {
            final timer = ref.read(timerServiceProvider);
            final pid = timer.activeProjectId ?? timer.lastProjectId;
            if (pid == null) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TimerScreen(projectId: pid)),
            );
          },
        ),
        const SizedBox(height: 8),
        // Project header with color, status, inline controls
        _ProjectHeader(
          project: project,
          isActiveProject: isActiveProject,
          isActiveAndRunning: isActiveAndRunning,
          isActiveAndPaused: isActiveAndPaused,
          hasParked: hasParked,
          projectColor: projectColor,
          statusColor: statusColor,
          onEdit: () => _editProject(project),
          onArchive: () => _archiveProject(project),
          onQuickWork: isActiveProject
              ? null // Inline controls handle this
              : (hasParked || timer.isActive && timer.activeProjectId != null && timer.activeProjectId != project.id)
                  ? () => _switchToHere(project)
                  : () => _startFocus(project),
        ),
        const SizedBox(height: 16),
        Text(project.name.toUpperCase(),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          (project.description?.isNotEmpty ?? false) ? project.description! : 'No description yet.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        _ProjectStatsRow(
          projectId: widget.projectId,
          todaySeconds: 0,
          weekSeconds: 0,
          monthSeconds: 0,
          projectColor: projectColor,
        ),
        if (project.dailyGoalMinutes > 0 || project.weeklyGoalMinutes > 0 || project.monthlyGoalMinutes > 0) ...[
          const SizedBox(height: 20),
          _ProjectGoalsSection(
            project: project,
            projectColor: projectColor,
          ),
        ],
        const SizedBox(height: 20),
        _LastActivity(projectId: widget.projectId),
        const SizedBox(height: 24),
        _NotesSection(projectId: widget.projectId, onChanged: _reload),
        const SizedBox(height: 24),
        _ContributionsSection(projectId: widget.projectId, onChanged: _reload),
        const SizedBox(height: 24),
        _HistorySection(projectId: widget.projectId),
        const SizedBox(height: 24),
      ],
    );
  }

  Color _colorFromString(String input) {
    final hash = input.codeUnits.fold<int>(0, (p, c) => p * 31 + c);
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.55, 0.85).toColor();
  }

  void _startFocus(models.Project project) {
    final id = project.id;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerScreen(projectId: id),
      ),
    );
  }

  void _switchToHere(models.Project project) {
    final id = project.id;
    if (id == null) return;
    final timer = ref.read(timerServiceProvider);
    timer.switchTo(id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TimerScreen(projectId: id)),
    );
  }

  void _editProject(models.Project project) {
    showDialog(
      context: context,
      builder: (_) => ProjectFormDialog(
        title: 'Edit project',
        initialName: project.name,
        initialDescription: project.description ?? '',
        initialDaily: project.dailyGoalMinutes,
        initialWeekly: project.weeklyGoalMinutes,
        initialMonthly: project.monthlyGoalMinutes,
        initialDays: parseGoalDays(project.goalDaysOfWeek),
        initialColor: project.color,
        onSave: (name, description, daily, weekly, monthly, days, color) async {
          final id = project.id;
          if (id == null) return;
          await ref.read(projectRepositoryProvider).update(
                id: id,
                name: name,
                description: description,
                dailyGoalMinutes: daily,
                weeklyGoalMinutes: weekly,
                monthlyGoalMinutes: monthly,
                goalDaysOfWeek: days,
                color: color,
              );
          _reload();
        },
      ),
    );
  }

  Future<void> _archiveProject(models.Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive project'),
        content: Text(
            'Archive "${project.name}"?\n\nIt will disappear from the dashboard but its history is preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed == true && project.id != null) {
      await ref.read(projectRepositoryProvider).archive(project.id!);
      if (mounted) Navigator.pop(context);
    }
  }
}

class _LastActivity extends ConsumerWidget {
  final int projectId;

  const _LastActivity({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSessionProvider(projectId)).value;
    if (recent == null) {
      return Center(
        child: Text('No sessions yet.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      );
    }
    return Center(
      child: Text(
        'Last activity: ${formatDayLabel(recent.startedAt)}',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
      ),
    );
  }
}

class _NotesSection extends ConsumerStatefulWidget {
  final int projectId;
  final VoidCallback onChanged;

  const _NotesSection({required this.projectId, required this.onChanged});

  @override
  ConsumerState<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<_NotesSection> {
  void _addNote() async {
    final title = await _promptText(context, title: 'Add note', label: 'Note', okText: 'Add note');
    if (title == null || title.trim().isEmpty) return;
    await ref.read(noteRepositoryProvider).create(projectId: widget.projectId, content: title.trim());
    widget.onChanged();
  }

  void _editNote(note_models.Note note) async {
    final title = await _promptText(context,
        title: 'Edit note', label: 'Note', initial: note.content, okText: 'Save');
    final id = note.id;
    if (id == null || title == null || title.trim().isEmpty || title.trim() == note.content) {
      return;
    }
    await ref.read(noteRepositoryProvider).update(id: id, content: title.trim());
    widget.onChanged();
  }

  Future<void> _deleteNote(note_models.Note note) async {
    final confirmed = await _confirm(context,
        title: 'Delete note', message: 'Delete note "${note.content}"?');
    final id = note.id;
    if (confirmed != true || id == null) return;
    await ref.read(noteRepositoryProvider).delete(id);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesForProjectProvider(widget.projectId)).value ?? <note_models.Note>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _addNote,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Note'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (notes.isEmpty)
          Text('Quick thoughts and ideas live here — no timer needed.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          ...notes.map((note) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 8),
                title: Text(note.content),
                subtitle: Text(formatDayLabel(note.updatedAt),
                    style: TextStyle(fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        onPressed: () => _editNote(note), icon: const Icon(Icons.edit, size: 18)),
                    IconButton(
                        onPressed: () => _deleteNote(note),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent)),
                  ],
                ),
              )),
      ],
    );
  }
}

class _ContributionsSection extends ConsumerStatefulWidget {
  final int projectId;
  final VoidCallback onChanged;

  const _ContributionsSection({required this.projectId, required this.onChanged});

  @override
  ConsumerState<_ContributionsSection> createState() => _ContributionsSectionState();
}

class _ContributionsSectionState extends ConsumerState<_ContributionsSection> {
  void _edit(db.Contribution c) async {
    final title = await _promptText(context,
        title: 'Edit contribution', label: 'Contribution', initial: c.title, okText: 'Save');
    if (title == null || title.trim().isEmpty || title.trim() == c.title) return;
    await ref.read(sessionRepositoryProvider).updateContribution(id: c.id, title: title.trim());
    widget.onChanged();
  }

  Future<void> _delete(db.Contribution c) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete contribution',
      message: "Delete '${c.title}'?\n\nThe session time is kept; only this entry is removed.",
    );
    if (confirmed != true) return;
    await ref.read(sessionRepositoryProvider).deleteContribution(c.id);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(contributionsForProjectProvider(widget.projectId)).value ?? <db.Contribution>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent contributions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text('Contributions come from focus sessions.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          ...items.take(8).map((c) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 8),
                title: Text(c.title),
                subtitle: Text(formatDayLabel(c.createdAt),
                    style: TextStyle(fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        onPressed: () => _edit(c), icon: const Icon(Icons.edit, size: 18)),
                    IconButton(
                        onPressed: () => _delete(c),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent)),
                  ],
                ),
              )),
      ],
    );
  }
}

class _HistorySection extends ConsumerWidget {
  final int projectId;

  const _HistorySection({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsForProjectProvider(projectId)).value ?? <db.Session>[];
    final counted = sessions.where((s) => s.status != 'running').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (counted.isEmpty)
          Text('No sessions yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          ...counted.take(20).map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(formatDayLabel(s.startedAt)),
                subtitle: Text('${formatDuration((s.duration ?? 0).round())} · ${s.status}'),
              )),
      ],
    );
  }
}

/// Project header with color dot, status badge, inline timer controls, and popup menu.
class _ProjectHeader extends ConsumerWidget {
  final models.Project project;
  final bool isActiveProject;
  final bool isActiveAndRunning;
  final bool isActiveAndPaused;
  final bool hasParked;
  final Color projectColor;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback? onQuickWork;

  const _ProjectHeader({
    required this.project,
    required this.isActiveProject,
    required this.isActiveAndRunning,
    required this.isActiveAndPaused,
    required this.hasParked,
    required this.projectColor,
    required this.statusColor,
    required this.onEdit,
    required this.onArchive,
    this.onQuickWork,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Project color indicator
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: projectColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (isActiveProject)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isActiveAndRunning ? 'ACTIVE' : (isActiveAndPaused ? 'PAUSED' : 'ACTIVE (idle)'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                )
              else if (hasParked)
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('PARKED', style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ),
        // Inline timer controls for active project
        if (isActiveProject) ...[
          Consumer(
            builder: (_, ref, __) {
              final timer = ref.read(timerServiceProvider);
              return IconButton(
                onPressed: timer.isRunning ? timer.pause : timer.resume,
                icon: Icon(timer.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                tooltip: timer.isRunning ? 'Pause' : 'Resume',
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  minimumSize: const Size(40, 40),
                ),
              );
            },
          ),
        ] else if (onQuickWork != null) ...[
          IconButton(
            onPressed: onQuickWork,
            icon: Icon(Icons.play_arrow_rounded),
            tooltip: 'Start focus',
            style: IconButton.styleFrom(
              backgroundColor: projectColor.withValues(alpha: 0.15),
              foregroundColor: projectColor,
            ),
          ),
        ],
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'archive') onArchive();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(Icons.archive), title: Text('Archive'), contentPadding: EdgeInsets.zero)),
          ],
          icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
          tooltip: 'More options',
        ),
      ],
    );
  }
}

/// Stats row with icon chips (Total, Sessions, Today, Parked, Notes, Last)
class _ProjectStatsRow extends ConsumerWidget {
  final int projectId;
  final int todaySeconds;
  final int weekSeconds;
  final int monthSeconds;
  final Color projectColor;

  const _ProjectStatsRow({
    required this.projectId,
    required this.todaySeconds,
    required this.weekSeconds,
    required this.monthSeconds,
    required this.projectColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalSecondsForProjectProvider(projectId));
    final todayAsync = ref.watch(todaySecondsForProjectProvider(projectId));
    final sessionCountAsync = ref.watch(sessionCountForProjectProvider(projectId));
    final contribCountAsync = ref.watch(contribCountForProjectProvider(projectId));
    final notesCountAsync = ref.watch(notesCountForProjectProvider(projectId));

    final total = totalAsync.value ?? 0;
    final today = todayAsync.value ?? 0;
    final sessions = sessionCountAsync.value ?? 0;
    final contribs = contribCountAsync.value ?? 0;
    final notes = notesCountAsync.value ?? 0;

    final parkedMap = ref.watch(parkedSessionsProvider).value ?? const <int, int>{};
    final parked = parkedMap[projectId] ?? 0;

    final chips = <Widget>[
      _StatChip(icon: Icons.timer_outlined, label: 'Total', value: formatDuration(total)),
      _StatChip(icon: Icons.repeat_outlined, label: 'Sessions', value: sessions.toString()),
    ];
    if (today > 0) {
      chips.add(_StatChip(icon: Icons.today_outlined, label: 'Today', value: formatDuration(today)));
    }
    if (parked > 0) {
      chips.add(_StatChip(icon: Icons.pause_circle_outline, label: 'Parked', value: formatDuration(parked)));
    }
    if (contribs > 0) {
      chips.add(_StatChip(icon: Icons.note_alt_outlined, label: 'Notes', value: contribs.toString()));
    }
    if (notes > 0) {
      chips.add(_StatChip(icon: Icons.edit_note, label: 'Notes', value: notes.toString()));
    }

    return Wrap(spacing: 8, runSpacing: 6, children: chips);
  }
}

/// Goal progress section with real progress
class _ProjectGoalsSection extends ConsumerWidget {
  final models.Project project;
  final Color projectColor;

  const _ProjectGoalsSection({required this.project, required this.projectColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final todayAsync = ref.watch(todaySecondsForProjectProvider(project.id!));
    final weekAsync = ref.watch(weekSecondsForProjectProvider(project.id!));
    final monthAsync = ref.watch(monthSecondsForProjectProvider(project.id!));

    final goals = <Widget>[];
    if (project.dailyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'Today',
        current: todayAsync.value ?? 0,
        target: (project.dailyGoalMinutes * 60).round(),
        color: projectColor,
      ));
    }
    if (project.weeklyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'This week',
        current: weekAsync.value ?? 0,
        target: (project.weeklyGoalMinutes * 60).round(),
        color: projectColor,
      ));
    }
    if (project.monthlyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'This month',
        current: monthAsync.value ?? 0,
        target: (project.monthlyGoalMinutes * 60).round(),
        color: projectColor,
      ));
    }
    final days = parseGoalDays(project.goalDaysOfWeek);
    if (days.isNotEmpty) {
      final activeDays = days.map((d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d]).join(', ');
      goals.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(Icons.event_repeat, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text('Active: $activeDays', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: goals);
  }
}

/// Stat chip with icon (reusable from dashboard)
class _StatChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;

  const _StatChip({this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text('$label: $value', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Goal progress bar (reusable from dashboard)
class _GoalProgress extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final Color color;

  const _GoalProgress({required this.label, required this.current, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final done = ratio >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label: ${formatDuration(current)} / ${formatDuration(target)}',
                style: TextStyle(color: done ? Colors.green : theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
            if (done) const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: done ? Colors.green : color,
          ),
        ),
      ],
    );
  }
}

/// Week seconds provider for project
final weekSecondsForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  final now = DateTime.now();
  final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  return sessions
      .where((s) =>
          (s.status == 'completed' || s.status == 'interrupted') &&
          !s.startedAt.isBefore(weekStart))
      .fold<int>(0, (sum, s) => sum + (s.duration ?? 0).round());
});

/// Month seconds provider for project
final monthSecondsForProjectProvider =
    FutureProvider.autoDispose.family<int, int>((ref, id) async {
  final sessions = ref.watch(sessionsForProjectProvider(id)).value ?? [];
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  return sessions
      .where((s) =>
          (s.status == 'completed' || s.status == 'interrupted') &&
          !s.startedAt.isBefore(monthStart))
      .fold<int>(0, (sum, s) => sum + (s.duration ?? 0).round());
});

Future<String?> _promptText(BuildContext context,
    {required String title, required String label, String initial = '', String okText = 'Save'}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(okText),
        ),
      ],
    ),
  );
}

Future<bool?> _confirm(BuildContext context, {required String title, required String message}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ),
  );
}
