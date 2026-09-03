import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart' as db;
import '../../models/project.dart' as models;
import '../../models/note.dart' as note_models;
import '../../providers/app_providers.dart';
import '../../utils/formatting.dart';
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('All projects'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => _editProject(project),
              child: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _archiveProject(project),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Archive'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(project.name.toUpperCase(),
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          (project.description?.isNotEmpty ?? false) ? project.description! : 'No description yet.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _StatsRow(projectId: widget.projectId),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.icon(
            onPressed: () => _startFocus(project),
            icon: const Icon(Icons.timer),
            label: const Text('Focus'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
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

  void _startFocus(models.Project project) {
    final id = project.id;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerScreen(projectId: id, startNow: true),
      ),
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
        onSave: (name, description, daily, weekly, monthly, days) async {
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

class _StatsRow extends ConsumerWidget {
  final int projectId;

  const _StatsRow({required this.projectId});

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

    final blocks = [
      (formatDuration(total), 'Time invested'),
      (formatDuration(today), 'Today'),
      ('$sessions', 'Sessions'),
      ('$contribs', 'Contributions'),
      ('$notes', 'Notes'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: blocks.map((b) {
            return SizedBox(
              width: (constraints.maxWidth / 5) - 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Text(b.$1,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(b.$2,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
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
