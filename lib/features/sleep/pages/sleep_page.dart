import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/sleep/data/sleep_entry.dart';
import 'package:streak/features/sleep/state/sleep_controller.dart';
import 'package:streak/features/sleep/widgets/sleep_log_sheet.dart';
import 'package:streak/features/sleep/widgets/sleep_stats_strip.dart';
import 'package:streak/features/sleep/widgets/sleep_timeline.dart';
import 'package:streak/features/sleep/widgets/sleep_analytics_section.dart';

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = AppClock.today();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Sleep Log'),
        actions: [
          Center(
            child: FilledButton.icon(
              onPressed: () => SleepLogSheet.show(context, day: today),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Log Today',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Body ──────────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.paddingOf(context).bottom + 120,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats strip
                const SleepStatsStrip(),
                const SizedBox(height: 28),

                // Timeline
                const SleepTimeline(),

                const SizedBox(height: 28),

                // Analytics Section
                const SleepAnalyticsSection(),

                const SizedBox(height: 28),

                // All entries list
                _AllEntriesSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yearly Heatmap ────────────────────────────────────────────────────────────

// ── All Entries List ──────────────────────────────────────────────────────────

class _AllEntriesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SleepController>();
    final entries = ctrl.entries;
    final scheme = Theme.of(context).colorScheme;

    if (entries.isEmpty) {
      return Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 16,
                color: Color(0xFF6C63FF),
              ),
              const SizedBox(width: 8),
              Text(
                'History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Icon(
            Icons.bedtime_rounded,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No sleep logged yet.\nTap + Log to record your first night.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 16,
              color: Color(0xFF6C63FF),
            ),
            const SizedBox(width: 8),
            Text(
              'History',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final entry in entries)
          _EntryTile(entry: entry, targetHours: ctrl.targetHours),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.targetHours});
  final SleepEntry entry;
  final double targetHours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hours = entry.hours;
    final color = _colorFor(hours, targetHours);
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    final dur = m == 0 ? '${h}h' : '${h}h ${m}m';

    String fmtTime(DateTime dt) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => SleepLogSheet.show(
            context,
            day: entry.wakeDay,
            existing: entry,
          ),
          onLongPress: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete entry?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              if (context.mounted) {
                await context.read<SleepController>().remove(entry.id);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.wakeDay.day}/${entry.wakeDay.month}/${entry.wakeDay.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        '${fmtTime(entry.bedTime)} → ${fmtTime(entry.wakeTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dur,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _colorFor(double hours, double goal) {
    final ratio = hours / goal;
    if (ratio >= 0.95) return const Color(0xFF4CAF50);
    if (ratio >= 0.80) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }
}
