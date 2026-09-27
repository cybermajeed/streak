import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/sleep/state/sleep_controller.dart';
import 'package:streak/features/statistics/widgets/stat_kit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SleepAnalyticsSection extends StatefulWidget {
  const SleepAnalyticsSection({super.key});

  @override
  State<SleepAnalyticsSection> createState() => _SleepAnalyticsSectionState();
}

class _SleepAnalyticsSectionState extends State<SleepAnalyticsSection> {
  int _tabIndex = 0; // 0 for Weekly, 1 for Monthly, 2 for Yearly
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SleepController>();
    final scheme = Theme.of(context).colorScheme;
    final today = AppClock.today();

    // Determine date range based on tab
    final days = _tabIndex == 0
        ? 7
        : _tabIndex == 1
        ? 30
        : 365;

    final offsetDays = _offset * days;
    final startDate = DateTime(
      today.year,
      today.month,
      today.day - (days - 1 + offsetDays),
    );
    final endDate = DateTime(today.year, today.month, today.day - offsetDays);

    // Aggregate sleep by day for the graph
    final dailyMap = <DateTime, double>{};
    for (var i = 0; i < days; i++) {
      final d = DateTime(startDate.year, startDate.month, startDate.day + i);
      dailyMap[d] = 0.0;
    }

    // Populate dailyMap with entries
    for (final e in ctrl.entries) {
      final key = e.wakeDay;
      if (dailyMap.containsKey(key)) {
        dailyMap[key] = dailyMap[key]! + e.hours;
      }
    }

    // Calculate metrics based on the currently viewed period
    int periodTracked = 0;
    int periodConsistent = 0;
    double periodTotalSleep = 0.0;

    for (final hours in dailyMap.values) {
      if (hours > 0) {
        // Only count days with logged sleep
        periodTracked++;
        periodTotalSleep += hours;
        if (hours >= ctrl.targetHours) {
          periodConsistent++;
        }
      }
    }

    final double avgSleep = periodTracked == 0
        ? 0
        : periodTotalSleep / periodTracked;
    final double consistencyPct = periodTracked == 0
        ? 0
        : (periodConsistent / periodTracked) * 100;

    final spots = <FlSpot>[];
    double maxY = ctrl.targetHours * 1.5;
    if (maxY < 12) maxY = 12;

    int idx = 0;
    final dateKeys = dailyMap.keys.toList()..sort();
    for (final d in dateKeys) {
      final h = dailyMap[d]!;
      spots.add(FlSpot(idx.toDouble(), h));
      if (h > maxY) maxY = h + 2;
      idx++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics_rounded, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Analysis',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _Tab(
                    label: 'Weekly',
                    selected: _tabIndex == 0,
                    onTap: () => setState(() {
                      _tabIndex = 0;
                      _offset = 0;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'Monthly',
                    selected: _tabIndex == 1,
                    onTap: () => setState(() {
                      _tabIndex = 1;
                      _offset = 0;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'Yearly',
                    selected: _tabIndex == 2,
                    onTap: () => setState(() {
                      _tabIndex = 2;
                      _offset = 0;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.chevronLeft,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _offset++),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _offset == 0
                        ? (_tabIndex == 0
                              ? 'This Week'
                              : _tabIndex == 1
                              ? 'This Month'
                              : 'This Year')
                        : _tabIndex == 2
                        ? '${endDate.year}'
                        : '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: _offset > 0
                          ? scheme.onSurfaceVariant
                          : scheme.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    onPressed: _offset > 0
                        ? () => setState(() => _offset--)
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHigh,
                      padding: const EdgeInsets.all(8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Chart
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                            minY: 0,
                            maxY: maxY,
                            minX: 0,
                            maxX: (days - 1).toDouble(),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final date = dateKeys[spot.x.toInt()];
                                    final dStr = DateFormat(
                                      'MMM d',
                                    ).format(date);
                                    return LineTooltipItem(
                                      '$dStr\n${spot.y.toStringAsFixed(1)}h',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 4,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.2,
                                ),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: 4,
                                  getTitlesWidget: (value, _) {
                                    return Text(
                                      '${value.toInt()}h',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant
                                            .withValues(
                                              alpha: 0.6,
                                            ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: _tabIndex == 0
                                      ? 1
                                      : _tabIndex == 1
                                      ? 6
                                      : 60,
                                  getTitlesWidget: (value, _) {
                                    final intValue = value.toInt();
                                    if (intValue < 0 ||
                                        intValue >= dateKeys.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final date = dateKeys[intValue];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _tabIndex == 0
                                            ? DateFormat('E').format(date)
                                            : _tabIndex == 1
                                            ? DateFormat('d').format(date)
                                            : DateFormat('MMM').format(date),
                                        style: TextStyle(
                                          color: scheme.onSurfaceVariant
                                              .withValues(
                                                alpha: 0.6,
                                              ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: ctrl.targetHours,
                                  color: scheme.primary,
                                  strokeWidth: 1.5,
                                  dashArray: [6, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(
                                      right: 4,
                                      bottom: 4,
                                    ),
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    labelResolver: (_) => 'GOAL',
                                  ),
                                ),
                              ],
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: scheme.primary,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: _tabIndex == 0),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: scheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                            ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Mini Stats
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MiniStat(
                  icon: LucideIcons.target,
                  color: scheme.primary,
                  value: '${consistencyPct.toStringAsFixed(0)}%',
                  label: 'Consistency',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MiniStat(
                  icon: LucideIcons.moonStar,
                  color: scheme.tertiary,
                  value: '${avgSleep.toStringAsFixed(1)}h',
                  label: 'Avg Sleep',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
