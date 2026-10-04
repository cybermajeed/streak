import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/sleep/data/sleep_entry.dart';
import 'package:streak/features/sleep/state/sleep_controller.dart';

class SleepLogSheet extends StatefulWidget {
  const SleepLogSheet({
    super.key,
    required this.initialDay,
    this.existing,
  });

  final DateTime initialDay;
  final SleepEntry? existing;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    SleepEntry? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => SleepLogSheet(initialDay: day, existing: existing),
    );
  }

  @override
  State<SleepLogSheet> createState() => _SleepLogSheetState();
}

class _SleepLogSheetState extends State<SleepLogSheet> {
  late DateTime _bed;
  late DateTime _wake;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _bed = widget.existing!.bedTime;
      _wake = widget.existing!.wakeTime;
    } else {
      // Default: bed at 11pm the night before, wake at 7am on chosen day
      final d = widget.initialDay;
      _bed = DateTime(d.year, d.month, d.day - 1, 23, 0);
      _wake = DateTime(d.year, d.month, d.day, 7, 0);
    }
  }

  Duration get _duration => _wake.difference(_bed);
  bool get _valid => !_wake.isBefore(_bed);

  Future<void> _pick({required bool isBed}) async {
    final current = isBed ? _bed : _wake;
    final chosenDay = widget.initialDay;

    // Bed: can be day-1 or day itself; Wake: can be day or day+1
    final first = isBed ? chosenDay.addDays(-1) : chosenDay;
    final last = isBed ? chosenDay : chosenDay.addDays(1);

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isBed) {
        _bed = picked;
      } else {
        _wake = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_valid) return;
    final controller = context.read<SleepController>();

    // Overlap validation
    for (final e in controller.entries) {
      if (widget.existing != null && e.id == widget.existing!.id) continue;
      if (_bed.isBefore(e.wakeTime) && _wake.isAfter(e.bedTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overlaps with an existing session')),
        );
        return;
      }
    }

    if (widget.existing != null) {
      await controller.remove(widget.existing!.id);
    }
    final entry = SleepEntry.create(bedTime: _bed, wakeTime: _wake);
    await controller.add(entry);
    if (mounted) Navigator.of(context).pop();
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = '${dt.day}/${dt.month}';
    return '$d  $h:$m';
  }

  String _durationText() {
    if (!_valid) return '--';
    final total = _duration.inMinutes;
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = const Color(0xFF6C63FF);

    return Padding(
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom +
            16,
        left: 24,
        right: 24,
        top: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing != null ? 'Edit Sleep' : 'Log Sleep',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a card to change the time',
            style: TextStyle(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _timeCard(
                  label: 'Bedtime',
                  dt: _bed,
                  isBed: true,
                  accent: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeCard(
                  label: 'Wake up',
                  dt: _wake,
                  isBed: false,
                  accent: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Duration pill
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _valid
                    ? accent.withValues(alpha: 0.12)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bedtime_rounded,
                    size: 16,
                    color: _valid ? accent : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _durationText(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _valid ? accent : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_valid) ...[
            const SizedBox(height: 12),
            const Text(
              'Wake time must be after bed time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              if (widget.existing != null) ...[
                Expanded(
                  flex: 1,
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await context.read<SleepController>().remove(
                        widget.existing!.id,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      foregroundColor: scheme.error,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Icon(Icons.delete_outline),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _valid ? _save : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeCard({
    required String label,
    required DateTime dt,
    required bool isBed,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _pick(isBed: isBed),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isBed ? Icons.bedtime_outlined : Icons.wb_sunny_outlined,
                    size: 14,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _fmt(dt),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
