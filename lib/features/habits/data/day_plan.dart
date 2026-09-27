import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/habits/data/habit.dart';

@immutable
class DaySlot {
  const DaySlot({required this.start, required this.end, this.habit});

  final int start;
  final int end;
  final Habit? habit;

  bool get isGap => habit == null;

  int get minutes => end - start;
}

@immutable
class DayPlan {
  const DayPlan({required this.slots, required this.anytime});

  final List<DaySlot> slots;
  final List<Habit> anytime;

  bool get isEmpty => slots.isEmpty && anytime.isEmpty;

  Iterable<Habit> get planned =>
      slots.where((s) => !s.isGap).map((s) => s.habit!);

  static bool isDueOn(Habit habit, DateTime day) =>
      !habit.isArchived &&
      habit.kind != HabitKind.negative &&
      !day.atMidnight.isBefore(habit.startedAt) &&
      habit.isScheduledOn(day) &&
      !habit.isPausedOn(day);

  static DayPlan of(List<Habit> habits, DateTime day) {
    final due = habits.where((h) => isDueOn(h, day)).toList();

    final events = <DaySlot>[];

    // 1. Add scheduled habits
    for (final h in due.where((h) => h.isPlanned)) {
      events.add(DaySlot(start: h.startMinute, end: h.endMinute, habit: h));
    }



    events.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      final byEnd = a.end.compareTo(b.end);
      return byEnd != 0
          ? byEnd
          : (a.habit?.order ?? 0).compareTo(b.habit?.order ?? 0);
    });

    final slots = <DaySlot>[];
    var reached = events.isEmpty ? 0 : math.min(0, events.first.start);
    for (final e in events) {
      if (e.start > reached) {
        slots.add(DaySlot(start: reached, end: e.start));
      }
      var s = e.start;
      if (s < reached) s = reached;
      if (e.end > s) {
        slots.add(DaySlot(start: s, end: e.end, habit: e.habit));
        if (e.end > reached) reached = e.end;
      }
    }

    return DayPlan(
      slots: slots,
      anytime: due.where((h) => !h.isPlanned).toList(),
    );
  }
}

String minuteLabel(int minute, {bool hour24 = true}) {
  var total = minute;
  while (total < 0) {
    total += 1440;
  }
  total = total % 1440;
  final h = total ~/ 60;
  final m = total % 60;
  if (hour24) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  final suffix = h < 12 ? 'AM' : 'PM';
  final display = h % 12 == 0 ? 12 : h % 12;
  return '$display:${m.toString().padLeft(2, '0')} $suffix';
}

String spanLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
