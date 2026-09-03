import 'package:flutter/material.dart';
import '../../models/app_settings.dart';

const _minMinutes = 1;
const _maxMinutes = 240;
const _minCycles = 2;
const _maxCycles = 8;

class SettingsDialog extends StatefulWidget {
  final AppSettings settings;
  final Future<void> Function(AppSettings) onSave;

  const SettingsDialog({super.key, required this.settings, required this.onSave});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _workController;
  late final TextEditingController _breakController;
  late final TextEditingController _longBreakController;
  late final TextEditingController _cyclesController;
  late bool _soundAlerts;
  late bool _autoStartAfterBreak;
  late bool _closeToTray;
  late bool _startInTray;
  late bool _startFilterCurrentDay;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _workController = TextEditingController(text: s.workMinutes.toString());
    _breakController = TextEditingController(text: s.breakMinutes.toString());
    _longBreakController = TextEditingController(text: s.longBreakMinutes.toString());
    _cyclesController = TextEditingController(text: s.cyclesBeforeLongBreak.toString());
    _soundAlerts = s.soundAlerts;
    _autoStartAfterBreak = s.autoStartAfterBreak;
    _closeToTray = s.closeToTray;
    _startInTray = s.startInTray;
    _startFilterCurrentDay = s.startFilterCurrentDay;
  }

  @override
  void dispose() {
    _workController.dispose();
    _breakController.dispose();
    _longBreakController.dispose();
    _cyclesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Timer settings'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Changes apply from the next session on.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _numberField(_workController, 'Focus length (minutes)'),
              const SizedBox(height: 12),
              _numberField(_breakController, 'Short break (minutes)'),
              const SizedBox(height: 12),
              _numberField(_longBreakController, 'Long break (minutes)'),
              const SizedBox(height: 12),
              _numberField(_cyclesController, 'Long break every N focus rounds'),
              const SizedBox(height: 16),
              _checkBox('Play sound alerts when a timer ends', _soundAlerts, (v) => _soundAlerts = v),
              _checkBox('Auto-start focus when a break ends', _autoStartAfterBreak, (v) => _autoStartAfterBreak = v),
              _checkBox('Close button minimizes to tray', _closeToTray, (v) => _closeToTray = v),
              _checkBox('Start minimized to tray on launch', _startInTray, (v) => _startInTray = v),
              _checkBox('Start dashboard filtered by today\'s weekday', _startFilterCurrentDay, (v) => _startFilterCurrentDay = v),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _checkBox(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: (v) => setState(() => onChanged(v ?? false)),
    );
  }

  void _save() {
    int parse(TextEditingController c) => int.tryParse(c.text.trim()) ?? -1;

    final work = parse(_workController);
    final brk = parse(_breakController);
    final longBreak = parse(_longBreakController);
    final cycles = parse(_cyclesController);

    if (work < _minMinutes || work > _maxMinutes) {
      setState(() => _error = 'Focus length must be between 1 and 240.');
      return;
    }
    if (brk < _minMinutes || brk > _maxMinutes) {
      setState(() => _error = 'Short break must be between 1 and 240.');
      return;
    }
    if (longBreak < _minMinutes || longBreak > _maxMinutes) {
      setState(() => _error = 'Long break must be between 1 and 240.');
      return;
    }
    if (cycles < _minCycles || cycles > _maxCycles) {
      setState(() => _error = 'Long break every N must be between 2 and 8.');
      return;
    }

    final updated = AppSettings(
      workMinutes: work,
      breakMinutes: brk,
      longBreakMinutes: longBreak,
      cyclesBeforeLongBreak: cycles,
      soundAlerts: _soundAlerts,
      autoStartAfterBreak: _autoStartAfterBreak,
      closeToTray: _closeToTray,
      startInTray: _startInTray,
      startFilterCurrentDay: _startFilterCurrentDay,
    );

    Navigator.pop(context);
    widget.onSave(updated);
  }
}
