import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/sleep/data/sleep_entry.dart';
import 'package:streak/features/sleep/state/sleep_controller.dart';
import 'package:streak/features/sleep/widgets/sleep_log_sheet.dart';

/// 7-night timeline. Each row = one night. Sleep blocks are drawn as
/// horizontal range bars proportional to a 24-hour clock axis.
class SleepTimeline extends StatefulWidget {
  const SleepTimeline({super.key});

  // Midnight to midnight
  static const _windowStart = 0.0;
  static const _windowEnd = 24.0;

  @override
  State<SleepTimeline> createState() => _SleepTimelineState();
}

class _SleepTimelineState extends State<SleepTimeline> {
  final PageController _pageController = PageController();
  double _scale = 1.0;
  double _baseScale = 1.0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SleepController>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.timeline_rounded,
                  size: 16,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(width: 8),
                Text(
                  'Past 7 nights',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            FilledButton.tonal(
              onPressed: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                'Today',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth * _scale;
              return GestureDetector(
                onScaleStart: (details) => _baseScale = _scale,
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = (_baseScale * details.scale).clamp(1.0, 6.0);
                  });
                },
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: _scale > 1.0
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AxisLabels(scheme: scheme, scale: _scale),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 7 * (_NightRow._rowH + 6), // 7 rows + spacing
                          child: PageView.builder(
                            controller: _pageController,
                            reverse: true,
                            itemBuilder: (context, pageIndex) {
                              final weekStartOffset = pageIndex * 7;
                              final days = List.generate(
                                7,
                                (i) => AppClock.today().addDays(
                                  -(weekStartOffset + i),
                                ),
                              );
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0; i < days.length; i++) ...[
                                    _NightRow(
                                      day: days[i],
                                      entries: ctrl.entriesForDay(days[i]),
                                      targetHours: ctrl.targetHours,
                                    ),
                                    if (i < days.length - 1)
                                      const SizedBox(height: 6),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.scheme, required this.scale});
  final ColorScheme scheme;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 46, right: 44),
      child: SizedBox(
        height: 16,
        width: double.infinity,
        child: CustomPaint(
          painter: _AxisLabelsPainter(scheme: scheme, scale: scale),
        ),
      ),
    );
  }
}

class _AxisLabelsPainter extends CustomPainter {
  _AxisLabelsPainter({required this.scheme, required this.scale});
  final ColorScheme scheme;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    int step = 6;
    if (scale > 4.0) {
      step = 1;
    } else if (scale > 2.0) {
      step = 3;
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int h = 0; h <= 24; h += step) {
      String label = '';
      if (h == 0 || h == 24) {
        label = '12am';
      } else if (h == 12) {
        label = '12pm';
      } else if (h < 12) {
        label = '${h}am';
      } else {
        label = '${h - 12}pm';
      }

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      );
      textPainter.layout();

      final x = (h / 24.0) * size.width;
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, 0));
    }
  }

  @override
  bool shouldRepaint(_AxisLabelsPainter old) =>
      old.scale != scale || old.scheme != scheme;
}

class _NightRow extends StatelessWidget {
  const _NightRow({
    required this.day,
    required this.entries,
    required this.targetHours,
  });

  final DateTime day;
  final List<SleepEntry> entries;
  final double targetHours;

  static const _rowH = 36.0;

  String _dayLabel() {
    final today = AppClock.today();
    if (day.isSameDay(today)) return 'Today';
    if (day.isSameDay(today.addDays(-1))) return 'Yest.';
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[day.weekday];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _rowH,
      child: Row(
        children: [
          // Day label
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dayLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: day.isSameDay(AppClock.today())
                        ? scheme.primary
                        : scheme.onSurface,
                  ),
                ),
                Text(
                  '${day.day}/${day.month}',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Bar area
          Expanded(
            child: SizedBox(
              height: _rowH,
              child: LayoutBuilder(
                builder: (_, constraints) => _BarCanvas(
                  width: constraints.maxWidth,
                  entries: entries,
                  targetHours: targetHours,
                  day: day,
                  dayTotalHours: _hoursForDay(),
                  scheme: scheme,
                ),
              ),
            ),
          ),
          // Duration label
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _durationText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: entries.isEmpty
                      ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                      : _colorFor(
                          _hoursForDay(),
                          targetHours,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _hoursForDay() {
    double total = 0.0;
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    for (final e in entries) {
      final start = e.bedTime.isBefore(startOfDay) ? startOfDay : e.bedTime;
      final end = e.wakeTime.isAfter(endOfDay) ? endOfDay : e.wakeTime;
      if (end.isAfter(start)) {
        total += end.difference(start).inMinutes / 60.0;
      }
    }
    return total;
  }

  String _durationText() {
    if (entries.isEmpty) return '';
    final total = _hoursForDay();
    final h = total.floor();
    final m = ((total - h) * 60).round();
    return m == 0 ? '${h}h' : '${h}h${m}m';
  }

  static Color _colorFor(double hours, double goal) {
    if (hours <= 0) return const Color(0xFF9E9E9E);
    final ratio = hours / goal;
    if (ratio >= 0.95) return const Color(0xFF4CAF50);
    if (ratio >= 0.80) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }
}

class _BarCanvas extends StatelessWidget {
  const _BarCanvas({
    required this.width,
    required this.entries,
    required this.targetHours,
    required this.day,
    required this.dayTotalHours,
    required this.scheme,
  });

  final double width;
  final List<SleepEntry> entries;
  final double targetHours;
  final DateTime day;
  final double dayTotalHours;
  final ColorScheme scheme;

  static const _wStart = SleepTimeline._windowStart;
  static const _wEnd = SleepTimeline._windowEnd;
  static const _wSpan = _wEnd - _wStart;

  double _xOf(double hour) => ((hour - _wStart) / _wSpan) * width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final x = details.localPosition.dx;
        SleepEntry? tappedEntry;

        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        for (final entry in entries) {
          final start = entry.bedTime.isBefore(dayStart)
              ? dayStart
              : entry.bedTime;
          final end = entry.wakeTime.isAfter(dayEnd) ? dayEnd : entry.wakeTime;

          if (end.isBefore(start) || end.isAtSameMomentAs(start)) continue;

          final startH = start.difference(dayStart).inMinutes / 60.0;
          final endH = end.difference(dayStart).inMinutes / 60.0;

          final x0 = _xOf(startH);
          final x1 = _xOf(endH);

          if (x >= x0 - 5 && x <= x1 + 5) {
            tappedEntry = entry;
            break;
          }
        }
        SleepLogSheet.show(context, day: day, existing: tappedEntry);
      },
      child: CustomPaint(
        size: Size(width, _NightRow._rowH),
        painter: _TimelinePainter(
          entries: entries,
          targetHours: targetHours,
          dayTotalHours: dayTotalHours,
          scheme: scheme,
          xOf: _xOf,
          day: day,
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.entries,
    required this.targetHours,
    required this.dayTotalHours,
    required this.scheme,
    required this.xOf,
    required this.day,
  });

  final List<SleepEntry> entries;
  final double targetHours;
  final double dayTotalHours;
  final ColorScheme scheme;
  final double Function(double) xOf;
  final DateTime day;

  static Color _colorFor(double hours, double goal) {
    final ratio = hours / goal;
    if (ratio >= 0.95) return const Color(0xFF4CAF50);
    if (ratio >= 0.80) return const Color(0xFFFF9800);
    return const Color(0xFFEF5350);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    // Track
    final trackRect = Rect.fromLTWH(0, size.height / 2 - 2, size.width, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(2)),
      trackPaint,
    );

    // Midnight divider (24.0) is technically at the end of the day, but wait:
    // the timeline goes from 12am (0) to 12am (24).
    // We can draw a divider at 12pm (noon) instead, or both?
    // Wait, let's keep the existing logic. 12am is at xOf(0) and xOf(24).
    final midnight = xOf(24.0);
    canvas.drawRect(
      Rect.fromLTWH(midnight - 0.5, 4, 1, size.height - 8),
      Paint()..color = scheme.onSurface.withValues(alpha: 0.18),
    );

    if (entries.isEmpty) {
      _drawDashed(canvas, size);
      return;
    }

    const barH = 22.0;
    final top = (size.height - barH) / 2;

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    for (final entry in entries) {
      final start = entry.bedTime.isBefore(dayStart) ? dayStart : entry.bedTime;
      final end = entry.wakeTime.isAfter(dayEnd) ? dayEnd : entry.wakeTime;

      if (end.isBefore(start) || end.isAtSameMomentAs(start)) continue;

      final startH = start.difference(dayStart).inMinutes / 60.0;
      final endH = end.difference(dayStart).inMinutes / 60.0;

      final x0 = xOf(startH.clamp(0.0, 24.0));
      final x1 = xOf(endH.clamp(0.0, 24.0));
      if (x1 <= x0) continue;

      final color = _colorFor(dayTotalHours, targetHours);

      final rect = Rect.fromLTWH(x0, top, x1 - x0, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = color.withValues(alpha: 0.25),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset(x0 + 5, size.height / 2),
        3,
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(x1 - 5, size.height / 2),
        3,
        Paint()..color = color,
      );
    }
  }

  void _drawDashed(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scheme.onSurface.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashW = 6.0;
    const gapW = 4.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashW).clamp(0, size.width), y),
        paint,
      );
      x += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.entries != entries ||
      old.targetHours != targetHours ||
      old.day != day;
}
