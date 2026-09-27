import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/features/sleep/state/sleep_controller.dart';

Future<void> showSleepGoalSheet(BuildContext context) async {
  final ctrl = context.read<SleepController>();
  double selected = ctrl.targetHours;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Sleep Goal',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: StatefulBuilder(
        builder: (_, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${selected.toStringAsFixed(selected % 1 == 0 ? 0 : 1)} hours',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6C63FF),
              ),
            ),
            Slider(
              value: selected,
              min: 4,
              max: 12,
              divisions: 16,
              activeColor: const Color(0xFF6C63FF),
              onChanged: (v) => setState(() => selected = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
          ),
          onPressed: () {
            ctrl.setTarget(selected);
            Navigator.pop(ctx);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
