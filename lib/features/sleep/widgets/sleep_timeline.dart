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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AxisLabels(scheme: scheme),
              const SizedBox(height: 8),
              SizedBox(
                height: 7 * (_NightRow._rowH + 6), // 7 rows + spacing
                child: PageView.builder(
                  controller: _pageController,
                  reverse:
                      true, // Page 0 is current week, page 1 is last week, etc
                  itemBuilder: (context, pageIndex) {
                    final weekStartOffset = pageIndex * 7;
                    final days = List.generate(
                      7,
                      (i) => AppClock.today().addDays(-(weekStartOffset + i)),
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
                          if (i < days.length - 1) const SizedBox(height: 6),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const labels = ['12am', '6am', '12pm', '6pm', '12am'];
    return Padding(
      padding: const EdgeInsets.only(left: 54, right: 44),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final l in labels)
            Text(
              l,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: entries.isEmpty
          ? () => SleepLogSheet.show(context, day: day)
          : null,
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
    return CustomPaint(
      size: Size(width, _NightRow._rowH),
      painter: _TimelinePainter(
        entries: entries,
        targetHours: targetHours,
        dayTotalHours: dayTotalHours,
        scheme: scheme,
        xOf: _xOf,
      ),
      child: entries.isNotEmpty
          ? _EntryTapLayer(entries: entries, day: day)
          : null,
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
  });

  final List<SleepEntry> entries;
  final double targetHours;
  final double dayTotalHours;
  final ColorScheme scheme;
  final double Function(double) xOf;

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

    // Midnight divider
    final midnight = xOf(24.0);
    canvas.drawRect(
      Rect.fromLTWH(midnight - 0.5, 4, 1, size.height - 8),
      Paint()..color = scheme.onSurface.withValues(alpha: 0.18),
    );

    if (entries.isEmpty) {
      // Dashed empty placeholder
      _drawDashed(canvas, size);
      return;
    }

    const barH = 22.0;
    final top = (size.height - barH) / 2;

    for (final entry in entries) {
      var startH = entry.bedTime.hour + entry.bedTime.minute / 60.0;
      var endH = entry.wakeTime.hour + entry.wakeTime.minute / 60.0;

      // Handle entries that span multiple days by clamping to 0-24 window.
      // If a sleep started yesterday and ended today, it's plotted from 00:00 to wakeTime today.
      if (entry.bedTime.isBefore(
        DateTime(entry.wakeDay.year, entry.wakeDay.month, entry.wakeDay.day),
      )) {
        startH = 0.0; // Started before midnight today
      }
      // If a sleep started today but ends tomorrow (shouldn't happen since wakeDay is the day it ends, but for safety):
      if (entry.wakeTime.isAfter(
        DateTime(
          entry.wakeDay.year,
          entry.wakeDay.month,
          entry.wakeDay.day,
          23,
          59,
          59,
        ),
      )) {
        endH = 24.0;
      }

      final x0 = xOf(startH.clamp(0.0, 24.0));
      final x1 = xOf(endH.clamp(0.0, 24.0));
      if (x1 <= x0) continue;

      final color = _colorFor(dayTotalHours, targetHours);

      final rect = Rect.fromLTWH(x0, top, x1 - x0, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = color.withValues(alpha: 0.25),
      );
      // Colored border
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Start cap dot
      canvas.drawCircle(
        Offset(x0 + 5, size.height / 2),
        3,
        Paint()..color = color,
      );
      // End cap dot
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
      old.entries != entries || old.targetHours != targetHours;
}

class _EntryTapLayer extends StatelessWidget {
  const _EntryTapLayer({required this.entries, required this.day});
  final List<SleepEntry> entries;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => SleepLogSheet.show(
        context,
        day: day,
        existing: entries.first,
      ),
    );
  }
}
