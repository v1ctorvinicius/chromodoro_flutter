import 'package:flutter/material.dart';

typedef ProjectSaveCallback = Future<void> Function(
  String name,
  String description,
  double daily,
  double weekly,
  double monthly,
  List<int> days,
  int color,
);

class ProjectFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialDescription;
  final double initialDaily;
  final double initialWeekly;
  final double initialMonthly;
  final List<int> initialDays;
  final int initialColor;
  final ProjectSaveCallback onSave;

  const ProjectFormDialog({
    super.key,
    required this.title,
    this.initialName,
    this.initialDescription,
    this.initialDaily = 0,
    this.initialWeekly = 0,
    this.initialMonthly = 0,
    this.initialDays = const [],
    this.initialColor = 0,
    required this.onSave,
  });

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dailyController;
  late final TextEditingController _weeklyController;
  late final TextEditingController _monthlyController;
  late Set<int> _selectedDays;
  int _selectedColor = 0;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _presetColors = [
    0xFF66BB6A, // green
    0xFFEF5350, // red
    0xFF42A5F5, // blue
    0xFFEC407A, // pink
    0xFF7E57C2, // purple
    0xFF26A69A, // teal
    0xFFFFA726, // orange
    0xFF9CCC65, // light green
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
    _dailyController = TextEditingController(text: _fmtGoal(widget.initialDaily));
    _weeklyController = TextEditingController(text: _fmtGoal(widget.initialWeekly));
    _monthlyController = TextEditingController(text: _fmtGoal(widget.initialMonthly));
    _selectedDays = widget.initialDays.toSet();
    _selectedColor = widget.initialColor;
  }

  String _fmtGoal(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dailyController.dispose();
    _weeklyController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dailyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Daily goal (min)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weeklyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Weekly goal (min)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _monthlyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monthly goal (min)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Active days', style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayNames.asMap().entries.map((e) {
                  final idx = e.key;
                  final day = e.value;
                  final selected = _selectedDays.contains(idx);
                  return FilterChip(
                    label: Text(day),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedDays.add(idx);
                        } else {
                          _selectedDays.remove(idx);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((c) {
                  final selected = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Row(
                children: [
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedColor = 0),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Auto'),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    final daily = double.tryParse(_dailyController.text.trim()) ?? 0;
    final weekly = double.tryParse(_weeklyController.text.trim()) ?? 0;
    final monthly = double.tryParse(_monthlyController.text.trim()) ?? 0;
    final days = _selectedDays.toList()..sort();
    Navigator.pop(context);
    widget.onSave(name, _descriptionController.text.trim(), daily, weekly, monthly, days, _selectedColor);
  }
}
