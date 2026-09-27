import 'package:flutter/material.dart';
import 'package:streak/core/database/local_store.dart';
import 'package:streak/core/extensions/date_extensions.dart';
import 'package:streak/features/sleep/data/sleep_entry.dart';

class SleepController extends ChangeNotifier {
  SleepController() {
    _entries = LocalStore.readSleepEntries();
    _targetHours = LocalStore.setting<double>(_targetKey, 8.0);
  }

  static const _targetKey = 'sleepTargetHours';

  late List<SleepEntry> _entries;
  late double _targetHours;

  List<SleepEntry> get entries {
    final sorted = [..._entries];
    sorted.sort((a, b) => b.wakeTime.compareTo(a.wakeTime));
    return sorted;
  }

  double get targetHours => _targetHours;

  // ── Analytics ───────────────────────────────────────────────────────────────

  List<SleepEntry> get last7Days {
    final cutoff = AppClock.today().addDays(-7);
    return entries.where((e) => !e.wakeDay.isBefore(cutoff)).toList();
  }

  double get averageHoursLast7 {
    final days = last7Days;
    if (days.isEmpty) return 0;
    // Group by day key and sum per day
    final byDay = <String, double>{};
    for (final e in days) {
      byDay[e.dayKey] = (byDay[e.dayKey] ?? 0) + e.hours;
    }
    return byDay.values.fold(0.0, (a, b) => a + b) / byDay.length;
  }

  SleepEntry? get lastNightEntry {
    if (entries.isEmpty) return null;
    return entries.first;
  }

  double get lastNightHours => lastNightEntry?.hours ?? 0;

  List<SleepEntry> entriesForDay(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return entries.where((e) =>
        e.bedTime.isBefore(endOfDay) && e.wakeTime.isAfter(startOfDay)).toList();
  }

  /// Returns the 7 nights to display in the timeline (today & 6 days back).
  List<DateTime> get timelineDays => [
        for (var i = 0; i < 7; i++) AppClock.today().addDays(-i),
      ];

  // ── Mutations ────────────────────────────────────────────────────────────────

  Future<void> add(SleepEntry entry) async {
    await LocalStore.writeSleepEntry(entry);
    _entries = LocalStore.readSleepEntries();
    notifyListeners();
  }

  void reload() {
    _entries = LocalStore.readSleepEntries();
    _targetHours = LocalStore.setting<double>(_targetKey, 8.0);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await LocalStore.removeSleepEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<void> setTarget(double hours) async {
    _targetHours = hours;
    await LocalStore.writeSetting(_targetKey, hours);
    notifyListeners();
  }
}
