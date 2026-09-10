import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/timer_service.dart';
import '../../utils/formatting.dart';
import '../../models/project.dart' as models;
import '../widgets/focus_bar.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/settings_dialog.dart';
import 'project_view_screen.dart';
import 'timer_screen.dart';
import 'stats_screen.dart';

/// Generates a consistent color from a string (e.g., project ID).
Color _colorFromString(String input) {
  final hash = input.codeUnits.fold<int>(0, (p, c) => p * 31 + c);
  final hue = (hash % 360).toDouble();
  return HSVColor.fromAHSV(1.0, hue, 0.55, 0.85).toColor();
}

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

    if (ref.read(miniSwitchRequestedProvider)) {
      ref.read(miniSwitchRequestedProvider.notifier).consume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showMiniSwitchDialog();
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
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
            _buildHeader(),
            const SizedBox(height: 8),
            _buildFilterBar(),
            Expanded(
              child: summariesAsync.when(
                data: (summaries) => _buildProjectList(summaries, activeSessionAsync, parkedAsync),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('v1.0.0',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
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
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
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
            onPressed: _openStats,
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
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
    final parkedMap = parkedAsync is AsyncData<Map<int, int>> ? parkedAsync.value : const <int, int>{};

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
        final project = summary.project;
        final timer = ref.watch(timerServiceProvider);
        final activeProjectId = timer.activeProjectId;
        final isOtherProjectActive = activeProjectId != null && activeProjectId != project.id;
        final hasParked = parkedMap.containsKey(project.id) && activeProjectId != project.id;
        final parkedSeconds = parkedMap[project.id] ?? 0;
        return _ProjectCard(
          summary: summary,
          onTap: () => _openProject(project),
          onQuickWork: isOtherProjectActive ? () => _switchToProject(project) : () => _quickWork(project),
          onQuickWorkIsSwitch: isOtherProjectActive,
          onEdit: () => _editProject(project),
          onArchive: () => _archiveProject(project),
          activeProjectId: activeProjectId,
          timerIsRunning: timer.isRunning,
          timerIsPaused: timer.state == TimerState.paused,
          hasParked: hasParked,
          parkedSeconds: parkedSeconds,
          todaySeconds: summary.todaySeconds,
          weekSeconds: 0,
          monthSeconds: 0,
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

  void _newProject() {
    showDialog(
      context: context,
      builder: (_) => ProjectFormDialog(
        title: 'New project',
        onSave: (name, description, daily, weekly, monthly, days, color) async {
          await ref.read(projectRepositoryProvider).create(
                name: name,
                description: description,
                dailyGoalMinutes: daily,
                weeklyGoalMinutes: weekly,
                monthlyGoalMinutes: monthly,
                goalDaysOfWeek: days,
                color: color,
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

  void _switchToProject(models.Project project) {
    final id = project.id;
    if (id == null) return;
    final timer = ref.read(timerServiceProvider);
    timer.switchTo(id);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TimerScreen(projectId: id)),
    ).then((_) {
      // After returning from TimerScreen, if we came from mini mode, re-enter it
      if (ref.read(miniSwitchRequestedProvider)) {
        ref.read(miniSwitchRequestedProvider.notifier).consume();
        ref.read(miniModeProvider.notifier).enter();
      }
    });
  }

  Future<void> _showMiniSwitchDialog() async {
    if (!mounted) return;
    final projects = ref.read(projectsProvider).value ?? const <models.Project>[];
    final timer = ref.read(timerServiceProvider);
    final parkedMap = ref.read(parkedSessionsProvider).value ?? const <int, int>{};
    // Only projects that currently have a parked session are switchable.
    final others = projects
        .where((p) =>
            p.id != timer.activeProjectId && parkedMap.containsKey(p.id))
        .toList();
    if (others.isEmpty) return;
    final chosen = await showDialog<models.Project>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch to project'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in others)
                ListTile(
                  dense: true,
                  title: Text(
                    '${p.name} · ${formatDuration(parkedMap[p.id] ?? 0)} parked',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(ctx, p),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      _switchToProject(chosen);
    } else if (mounted) {
      // User cancelled the switch dialog - re-enter mini mode
      ref.read(miniModeProvider.notifier).enter();
    }
  }

  void _quickWork(models.Project project) {
    final id = project.id;
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TimerScreen(projectId: id)),
    );
  }

  void _openSettings() async {
    final current = ref.read(settingsNotifierProvider);
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

  void _openStats() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StatsScreen()),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final ProjectSummary summary;
  final VoidCallback onTap;
  final VoidCallback onQuickWork;
  final bool onQuickWorkIsSwitch;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final int? activeProjectId;
  final bool timerIsRunning;
  final bool timerIsPaused;
  final bool hasParked;
  final int parkedSeconds;
  final int todaySeconds;
  final int weekSeconds;
  final int monthSeconds;

  const _ProjectCard({
    required this.summary,
    required this.onTap,
    required this.onQuickWork,
    this.onQuickWorkIsSwitch = false,
    required this.onEdit,
    required this.onArchive,
    this.activeProjectId,
    this.timerIsRunning = false,
    this.timerIsPaused = false,
    this.hasParked = false,
    this.parkedSeconds = 0,
    this.todaySeconds = 0,
    this.weekSeconds = 0,
    this.monthSeconds = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = summary.project;
    final theme = Theme.of(context);
    final isActiveProject = activeProjectId == p.id;
    final isActiveAndRunning = isActiveProject && timerIsRunning;
    final isActiveAndPaused = isActiveProject && timerIsPaused;
    final isParked = !isActiveProject && hasParked;

    // User-defined project color (if set), else generated from ID, else primary.
    final projectColor = p.color != 0 ? Color(p.color) : _colorFromString(p.id?.toString() ?? '0');
    final statusColor = isActiveAndRunning
        ? const Color(0xFF66BB6A)
        : (isActiveAndPaused || isParked)
            ? const Color(0xFFFFB74D)
            : theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActiveProject ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActiveProject
            ? BorderSide(color: statusColor, width: 2)
            : BorderSide.none,
      ),
      color: isActiveProject
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, p, isActiveProject, isActiveAndRunning, isActiveAndPaused, isParked, projectColor, statusColor),
              if (p.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(p.description!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 12),
              _buildStatsRow(theme, isParked),
              if (summary.dailyGoalMinutes > 0 || summary.weeklyGoalMinutes > 0 || summary.monthlyGoalMinutes > 0) ...[
                const SizedBox(height: 16),
                _buildGoalsSection(theme, summary, projectColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, models.Project p, bool isActiveProject,
      bool isRunning, bool isPaused, bool isParked, Color projectColor, Color statusColor) {
    return Row(
      children: [
        // Project color indicator (user-defined or generated)
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: projectColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (isActiveProject)
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isRunning ? 'ACTIVE' : (isPaused ? 'PAUSED' : 'ACTIVE (idle)'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                )
              else if (isParked)
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('PARKED', style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ),
        // Quick actions
        if (isActiveProject) ...[
          // Inline timer controls for active project
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
                  minimumSize: const Size(36, 36),
                ),
              );
            },
          ),
        ] else ...[
          IconButton(
            onPressed: onQuickWork,
            icon: Icon(onQuickWorkIsSwitch ? Icons.swap_horiz : Icons.play_arrow_rounded),
            tooltip: onQuickWorkIsSwitch ? 'Switch to this project' : 'Start focus',
            style: IconButton.styleFrom(
              backgroundColor: onQuickWorkIsSwitch ? theme.colorScheme.surfaceContainerHighest : projectColor.withValues(alpha: 0.15),
              foregroundColor: onQuickWorkIsSwitch ? theme.colorScheme.onSurfaceVariant : projectColor,
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

  Widget _buildStatsRow(ThemeData theme, bool isParked) {
    final children = <Widget>[
      _StatChip(icon: Icons.timer_outlined, label: 'Total', value: formatDuration(summary.totalSeconds)),
      _StatChip(icon: Icons.repeat_outlined, label: 'Sessions', value: summary.sessionCount.toString()),
    ];
    if (summary.todaySeconds > 0) {
      children.add(_StatChip(icon: Icons.today_outlined, label: 'Today', value: formatDuration(summary.todaySeconds)));
    }
    if (isParked && parkedSeconds > 0) {
      children.add(_StatChip(icon: Icons.pause_circle_outline, label: 'Parked', value: formatDuration(parkedSeconds)));
    }
    if (summary.contributionCount > 0) {
      children.add(_StatChip(icon: Icons.note_alt_outlined, label: 'Notes', value: summary.contributionCount.toString()));
    }
    if (summary.lastActivity != null) {
      children.add(_StatChip(icon: Icons.history_outlined, label: 'Last', value: formatDayLabel(summary.lastActivity!)));
    }
    return Wrap(spacing: 8, runSpacing: 6, children: children);
  }

  Widget _buildGoalsSection(ThemeData theme, ProjectSummary summary, Color projectColor) {
    final goals = <Widget>[];
    if (summary.dailyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'Today',
        current: todaySeconds,
        target: (summary.dailyGoalMinutes * 60).round(),
        color: projectColor,
      ));
    }
    if (summary.weeklyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'This week',
        current: weekSeconds,
        target: (summary.weeklyGoalMinutes * 60).round(),
        color: projectColor,
      ));
    }
    if (summary.monthlyGoalMinutes > 0) {
      goals.add(_GoalProgress(
        label: 'This month',
        current: monthSeconds,
        target: (summary.monthlyGoalMinutes * 60).round(),
        color: projectColor,
      ));
    }
    final days = parseGoalDays(summary.goalDaysOfWeek);
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