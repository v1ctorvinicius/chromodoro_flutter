import 'package:flutter/material.dart';

class RecoveryDialog extends StatelessWidget {
  final String projectName;
  final DateTime startedAt;
  final int elapsedSeconds;

  const RecoveryDialog({
    super.key,
    required this.projectName,
    required this.startedAt,
    required this.elapsedSeconds,
  });

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '$m:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = startedAt.toLocal();
    final timeStr =
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    return AlertDialog(
      title: const Text('Interrupted focus session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"$projectName"',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              'There was a session in progress when the app closed last time.\n'
              'Started at $timeStr · elapsed $_formatElapsed($elapsedSeconds)'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'resume'),
          child: const Text('Resume'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'finish'),
          child: const Text('Finish & log'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}
