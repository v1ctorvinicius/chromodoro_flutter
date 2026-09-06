import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import '../../providers/app_providers.dart';
import '../../utils/formatting.dart';

/// Statistics screen: shares the dashboard's footer content (global totals,
/// weekly bar and data exports) so the dashboard itself stays clean.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = ref.watch(globalTotalsProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: const Text('Statistics'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _TotalCard(
                    label: 'Today',
                    value: formatDurationShort(totals?.today ?? 0),
                    icon: Icons.today,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TotalCard(
                    label: 'This week',
                    value: formatDurationShort(totals?.week ?? 0),
                    icon: Icons.date_range,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FooterButton(label: 'Export sessions', onPressed: _exportSessions),
                      _FooterButton(label: 'Export contributions', onPressed: _exportContributions),
                      _FooterButton(label: 'Backup database', onPressed: _backupDatabase),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('v1.0.0',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  String _todayStamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _exportSessions() => _saveAndRun(
        suggestedName: 'chromodoro-sessions-${_todayStamp()}.csv',
        extension: 'csv',
        run: (path) async {
          final count = await ref.read(projectRepositoryProvider).exportSessionsCsv(path);
          _showExportResult('$count sessions written to\n$path');
        },
      );

  Future<void> _exportContributions() => _saveAndRun(
        suggestedName: 'chromodoro-contributions-${_todayStamp()}.csv',
        extension: 'csv',
        run: (path) async {
          final count = await ref.read(projectRepositoryProvider).exportContributionsCsv(path);
          _showExportResult('$count contributions written to\n$path');
        },
      );

  Future<void> _backupDatabase() => _saveAndRun(
        suggestedName: 'chromodoro-backup-${_todayStamp()}.db',
        extension: 'db',
        run: (path) async {
          await ref.read(projectRepositoryProvider).backupDatabase(path);
          _showExportResult('Database copied to\n$path');
        },
      );

  Future<void> _saveAndRun({
    required String suggestedName,
    required String extension,
    required Future<void> Function(String path) run,
  }) async {
    if (!mounted) return;
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(label: extension.toUpperCase(), extensions: [extension]),
      ],
    );
    if (location == null || !mounted) return;
    try {
      await run(location.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _showExportResult(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TotalCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _FooterButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }
}