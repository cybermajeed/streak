import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/features/sleep/state/sleep_controller.dart';

class SleepStatsStrip extends StatelessWidget {
  const SleepStatsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SleepController>();
    final last = ctrl.lastNightHours;
    final avg = ctrl.averageHoursLast7;
    final goal = ctrl.targetHours;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Last Night',
            value: _fmtH(last),
            icon: Icons.bedtime_rounded,
            color: _colorFor(last, goal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: '7-Day Avg',
            value: _fmtH(avg),
            icon: Icons.bar_chart_rounded,
            color: _colorFor(avg, goal),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Goal',
            value: _fmtH(goal),
            icon: Icons.flag_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  static Color _colorFor(double hours, double goal) {
    if (hours <= 0) return const Color(0xFF9E9E9E);
    final ratio = hours / goal;
    if (ratio >= 0.95) return const Color(0xFF4CAF50);
    if (ratio >= 0.80) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  static String _fmtH(double hours) {
    if (hours <= 0) return '--';
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
