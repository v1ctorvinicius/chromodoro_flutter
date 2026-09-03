import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../utils/formatting.dart';
import '../../models/project.dart' as models;
import '../widgets/project_form_dialog.dart';
import '../widgets/settings_dialog.dart';
import 'project_view_screen.dart';
import 'timer_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _periodFilter = 'All time';
  String _goalFilter = 'All';
  String _activityFilter = 'All';
  String _sortBy = 'Last activity';
  String _dayFilter = 'Any';

  final _dayNames = ['Any', 'Every day', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadInitialDayFilter();
  }

  Future<void> _loadInitialDayFilter() async {
    final settings = await ref.read(settingsProvider.future);
    if (settings.startFilterCurrentDay) {
      final weekday = DateTime.now().weekday; // 1=Mon...7=Sun
      final dayIndex = weekday - 1;
      setState(() {
        _dayFilter = _dayNames[dayIndex + 2]; // +2 because Any=0, Every day=1
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summariesAsync = ref.watch(projectSummariesProvider);
    final activeSessionAsync = ref.watch(activeSessionProvider);
    final parkedAsync = ref.watch(parkedSessionsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            Expanded(
              child: summariesAsync.when(
                data: (summaries) => _buildProjectList(summaries, activeSessionAsync, parkedAsync),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
            _buildFooter(activeSessionAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Text('Projects', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const Spacer(),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'type a project name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _newProject,
            icon: const Icon(Icons.add),
            label: const Text('New project'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          // Day selector - primary filter
          Row(
            children: [
              Text('Day', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _dayNames.map((day) {
                      final isSelected = _dayFilter == day;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _dayFilter = day),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Secondary filters
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildFilterDropdown('Period', _periodFilter, ['All time', 'Today', 'This week', 'This month'], (v) => setState(() => _periodFilter = v!)),
              _buildFilterDropdown('Goals', _goalFilter, ['All', 'With goal', 'No goal', 'Achieved', 'Pending'], (v) => setState(() => _goalFilter = v!)),
              _buildFilterDropdown('Activity', _activityFilter, ['All', 'Active today', 'Active this week', 'Inactive 7d+'], (v) => setState(() => _activityFilter = v!)),
              _buildFilterDropdown('Sort', _sortBy, ['Last activity', 'Name', 'Total time', 'Sessions'], (v) => setState(() => _sortBy = v!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildProjectList(List<ProjectSummary> summaries, AsyncValue activeSessionAsync, AsyncValue parkedAsync) {
    final filtered = _filterSummaries(summaries);
    final sorted = _sortSummaries(filtered);

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No projects yet.\nCreate one and start accumulating focused work.' : 'No matching projects.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final summary = sorted[index];
        return _ProjectCard(
          summary: summary,
          onTap: () => _openProject(summary.project),
          onQuickWork: () => _quickWork(summary.project),
          onEdit: () => _editProject(summary.project),
          onArchive: () => _archiveProject(summary.project),
        );
      },
    );
  }

  List<ProjectSummary> _filterSummaries(List<ProjectSummary> summaries) {
    return summaries.where((s) {
      final p = s.project;
      // Search
      if (_searchQuery.isNotEmpty && !p.name.toLowerCase().contains(_searchQuery)) return false;
      
      // Period filter
      if (_periodFilter != 'All time' && s.lastActivity != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final monthStart = DateTime(now.year, now.month, 1);
        final la = s.lastActivity!;
        if (_periodFilter == 'Today' && la.isBefore(today)) return false;
        if (_periodFilter == 'This week' && la.isBefore(weekStart)) return false;
        if (_periodFilter == 'This month' && la.isBefore(monthStart)) return false;
      }
      
      // Goals filter
      final hasGoal = p.dailyGoalMinutes > 0 || p.weeklyGoalMinutes > 0 || p.monthlyGoalMinutes > 0;
      if (_goalFilter == 'With goal' && !hasGoal) return false;
      if (_goalFilter == 'No goal' && hasGoal) return false;
      if (_goalFilter == 'Achieved' || _goalFilter == 'Pending') {
        if (!hasGoal) return false;
        final achieved = _checkAnyGoalAchieved(p);
        if (_goalFilter == 'Achieved' && !achieved) return false;
        if (_goalFilter == 'Pending' && achieved) return false;
      }
      
      // Activity filter
      if (_activityFilter != 'All' && s.lastActivity != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final la = s.lastActivity!;
        if (_activityFilter == 'Active today' && la.isBefore(today)) return false;
        if (_activityFilter == 'Active this week' && la.isBefore(weekStart)) return false;
        if (_activityFilter == 'Inactive 7d+' && la.isAfter(today.subtract(const Duration(days: 7)))) return false;
      }
      
      // Day filter
      if (_dayFilter != 'Any') {
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = parseGoalDays(p.goalDaysOfWeek);
        if (_dayFilter == 'Every day') {
          if (days.length != 7) return false;
        } else {
          final idx = dayNames.indexOf(_dayFilter);
          if (idx >= 0) {
            if (days.isEmpty || !days.contains(idx)) return false;
          }
        }
      }
      
      return true;
    }).toList();
  }

  bool _checkAnyGoalAchieved(models.Project p) {
    return false;
  }

  List<ProjectSummary> _sortSummaries(List<ProjectSummary> summaries) {
    final list = List<ProjectSummary>.from(summaries);
    switch (_sortBy) {
      case 'Name':
        list.sort((a, b) => a.project.name.compareTo(b.project.name));
        break;
      case 'Total time':
        list.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
        break;
      case 'Sessions':
        list.sort((a, b) => b.sessionCount.compareTo(a.sessionCount));
        break;
      default: // Last activity
        list.sort((a, b) {
          if (a.lastActivity == null && b.lastActivity == null) return 0;
          if (a.lastActivity == null) return 1;
          if (b.lastActivity == null) return -1;
          return b.lastActivity!.compareTo(a.lastActivity!);
        });
    }
    return list;
  }

  Widget _buildFooter(AsyncValue activeSessionAsync) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('v1.0.0', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _newProject() {
    showDialog(
      context: context,
      builder: (_) => ProjectFormDialog(
        title: 'New project',
        onSave: (name, description, daily, weekly, monthly, days) async {
          await ref.read(projectRepositoryProvider).create(
                name: name,
                description: description,
                dailyGoalMinutes: daily,
                weeklyGoalMinutes: weekly,
                monthlyGoalMinutes: monthly,
                goalDaysOfWeek: days,
              );
        },
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
        },
      ),
    );
  }

  void _archiveProject(models.Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive project'),
        content: Text('Archive "${project.name}"? It will be hidden from the dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed == true && project.id != null) {
      await ref.read(projectRepositoryProvider).archive(project.id!);
    }
  }

  void _openProject(models.Project project) {
    final id = project.id;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectViewScreen(projectId: id)),
    );
  }

  void _quickWork(models.Project project) {
    final id = project.id;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerScreen(projectId: id, startNow: true),
      ),
    );
  }

  void _openSettings() async {
    final current = await ref.read(settingsProvider.future);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        settings: current,
        onSave: (updated) async {
          await ref.read(settingsNotifierProvider.notifier).save(updated);
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectSummary summary;
  final VoidCallback onTap;
  final VoidCallback onQuickWork;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _ProjectCard({
    required this.summary,
    required this.onTap,
    required this.onQuickWork,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final p = summary.project;
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(p.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(onPressed: onQuickWork, icon: const Icon(Icons.play_arrow), tooltip: 'Focus'),
                      IconButton(onPressed: onEdit, icon: const Icon(Icons.edit), tooltip: 'Edit'),
                      IconButton(onPressed: onArchive, icon: const Icon(Icons.archive), tooltip: 'Archive'),
                    ],
                  ),
                ],
              ),
              if (p.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(p.description!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _StatChip(label: 'Total', value: formatDuration(summary.totalSeconds)),
                  _StatChip(label: 'Sessions', value: summary.sessionCount.toString()),
                  if (summary.todaySeconds > 0)
                    _StatChip(label: 'Today', value: formatDuration(summary.todaySeconds)),
                  if (summary.contributionCount > 0)
                    _StatChip(label: 'Contributions', value: summary.contributionCount.toString()),
                  if (summary.lastActivity != null)
                    _StatChip(label: 'Last', value: formatDayLabel(summary.lastActivity!)),
                ],
              ),
              if (summary.dailyGoalMinutes > 0 || summary.weeklyGoalMinutes > 0 || summary.monthlyGoalMinutes > 0) ...[
                const SizedBox(height: 12),
                _buildGoalsSection(summary, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalsSection(ProjectSummary summary, ThemeData theme) {
    final goals = <Widget>[];
    
    if (summary.dailyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'Today',
        current: 0,
        target: (summary.dailyGoalMinutes * 60).round(),
      ));
    }
    if (summary.weeklyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'This week',
        current: 0,
        target: (summary.weeklyGoalMinutes * 60).round(),
      ));
    }
    if (summary.monthlyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'This month',
        current: 0,
        target: (summary.monthlyGoalMinutes * 60).round(),
      ));
    }
    
    final days = parseGoalDays(summary.goalDaysOfWeek);
    if (days.isNotEmpty) {
      final activeDays = days.map((d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d]).join(', ');
      goals.add(Text('Active: $activeDays', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: goals,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  final String label;
  final int current;
  final int target;

  const _GoalProgress({required this.label, required this.current, required this.target});

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
                style: TextStyle(color: done ? Colors.green : theme.colorScheme.onSurfaceVariant, fontSize: 12)),
            if (done) const Icon(Icons.check_circle, color: Colors.green, size: 16),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: ratio, backgroundColor: theme.colorScheme.surfaceContainerHighest, color: done ? Colors.green : theme.colorScheme.primary),
      ],
    );
  }
}