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
  int _tabIndex = 0; // 0 for Weekly, 1 for Monthly

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
    final startDate = today.subtract(Duration(days: days - 1));

    // Aggregate sleep by day
    final dailyMap = <DateTime, double>{};
    for (var i = 0; i < days; i++) {
      dailyMap[startDate.add(Duration(days: i))] = 0.0;
    }

    // We only compute metrics for the days that actually have entries, or for all days?
    // Let's compute based on all tracked days overall for consistency stat, or just the range?
    // The prompt says "instead of only yearly view show the full consistency percentage, analysis, graph(weekly, montlhy), statiscs components etc in there".
    // Let's calculate overall stats for the mini stats, and range-specific for the graph.

    final overallDailyMap = <String, double>{};
    for (final e in ctrl.entries) {
      overallDailyMap[e.dayKey] = (overallDailyMap[e.dayKey] ?? 0.0) + e.hours;
    }

    int overallTracked = overallDailyMap.length;
    int overallConsistent = 0;
    double overallTotalSleep = 0;

    for (final hours in overallDailyMap.values) {
      overallTotalSleep += hours;
      if (hours >= ctrl.targetHours) {
        overallConsistent++;
      }
    }

    double avgSleep = overallTracked == 0
        ? 0
        : overallTotalSleep / overallTracked;
    double consistencyPct = overallTracked == 0
        ? 0
        : (overallConsistent / overallTracked) * 100;

    // Graph Data
    for (final e in ctrl.entries) {
      final key = e.wakeDay;
      if (dailyMap.containsKey(key)) {
        dailyMap[key] = dailyMap[key]! + e.hours;
      }
    }

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
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'Monthly',
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                  const SizedBox(width: 8),
                  _Tab(
                    label: 'Yearly',
                    selected: _tabIndex == 2,
                    onTap: () => setState(() => _tabIndex = 2),
                  ),
                ],
              ),
              const SizedBox(height: 32),
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
                            final dStr = DateFormat('MMM d').format(date);
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
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
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
                                color: scheme.onSurfaceVariant.withValues(
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
                            if (intValue < 0 || intValue >= dateKeys.length)
                              return const SizedBox.shrink();
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
                                  color: scheme.onSurfaceVariant.withValues(
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
                            padding: const EdgeInsets.only(right: 4, bottom: 4),
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            labelResolver: (line) => 'GOAL',
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
                        dotData: FlDotData(
                          show: _tabIndex == 0,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: scheme.primary,
                              strokeWidth: 2,
                              strokeColor: scheme.surface,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withValues(alpha: 0.2),
                              scheme.primary.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Stats
              Row(
                children: [
                  Expanded(
                    child: MiniStat(
                      value: '${consistencyPct.round()}%',
                      label: 'Consistency',
                      icon: LucideIcons.target,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MiniStat(
                      value: avgSleep.toStringAsFixed(1),
                      label: 'Avg Hours',
                      icon: LucideIcons.moon,
                      color: const Color(0xFF6C63FF),
                      unit: 'h',
                    ),
                  ),
                ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
