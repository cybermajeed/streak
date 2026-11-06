import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:streak/core/database/data_location.dart';
import 'package:streak/core/utils/app_dirs.dart';
import 'package:streak/features/habits/data/category.dart';
import 'package:streak/features/habits/data/habit.dart';
import 'package:streak/features/focus/data/focus_session.dart';
import 'package:streak/features/habits/data/habit_note.dart';
import 'package:streak/features/sleep/data/sleep_entry.dart';

class LocalStore {
  const LocalStore._();

  static const _habitsBox = 'habits';
  static const _settingsBox = 'settings';
  static const _categoriesBox = 'categories';
  static const _notesBox = 'notes';
  static const _focusBox = 'focus';
  static const _sleepBox = 'sleep';
  static const _changesKey = 'syncChanges';
  static const _deletedKey = 'syncDeleted';
  static const _clearedKey = 'syncCleared';
  static const _daysKey = 'syncDays';
  static const _deviceKey = 'deviceId';
  static const _quietZone = #streakQuiet;
  static const _forgetAfter = Duration(days: 120);

  static late Box _habits;
  static late Box _settings;
  static late Box _categories;
  static late Box _notes;
  static late Box _focus;
  static late Box _sleep;

  static int _writing = 0;
  static String _habitsStamp = '';

  static bool get isWriting => _writing > 0;

  static void Function()? onChanged;
  static Map<String, int>? _changes;
  static Map<String, int>? _deleted;
  static Map<String, int>? _cleared;
  static Map<String, int>? _days;
  static Completer<void>? _idle;

  static Map<String, int> _stamps(String key) => {
        for (final entry in settingMap(key).entries)
          if (entry.value is int) entry.key: entry.value as int,
      };

  static Map<String, int> get changes => _changes ??= _stamps(_changesKey);

  static Map<String, int> get deleted => _deleted ??= _forgetOld(_stamps(_deletedKey));

  static Map<String, int> get cleared => _cleared ??= _stamps(_clearedKey);

  static Map<String, int> get days => _days ??= _forgetOld(_stamps(_daysKey));

  static Map<String, int> _forgetOld(Map<String, int> marks) {
    final limit = DateTime.now().subtract(_forgetAfter).millisecondsSinceEpoch;
    return marks..removeWhere((_, at) => at < limit);
  }

  static int? changedAt(String id) => changes[id];

  static int? deletedAt(String id) => deleted[id];

  static int? clearedAt(String id) => cleared[id];

  static bool get _tracking => setting('autoBackupFolder', '').isNotEmpty;

  static bool get _quiet => Zone.current[_quietZone] == true;

  static Future<void> stampChange(String id, int at) async {
    changes[id] = at;
    await _settings.put(_changesKey, Map<String, int>.of(changes));
    if (deleted.remove(id) != null) {
      await _settings.put(_deletedKey, Map<String, int>.of(deleted));
    }
  }

  static Future<void> stampDeleted(String id, int at) async {
    deleted[id] = at;
    changes.remove(id);
    await _settings.put(_deletedKey, Map<String, int>.of(deleted));
    await _settings.put(_changesKey, Map<String, int>.of(changes));
  }

  static Future<void> stampCleared(Iterable<String> ids, int at) async {
    for (final id in ids) {
      cleared[id] = at;
    }
    await _settings.put(_clearedKey, Map<String, int>.of(cleared));
  }

  static Future<void> stampDays(Map<String, int> marks) async {
    if (marks.isEmpty) return;
    days.addAll(marks);
    await _settings.put(_daysKey, Map<String, int>.of(days));
  }

  static Future<void> _touchDays(Habit habit) async {
    if (_quiet || !_tracking) return;
    final before = LocalStore.habit(habit.id)?.completions ?? const {};
    final now = DateTime.now().millisecondsSinceEpoch;
    await stampDays({
      for (final day in {...before.keys, ...habit.completions.keys})
        if (jsonEncode(before[day]?.toMap()) !=
            jsonEncode(habit.completions[day]?.toMap()))
          '${habit.id}|$day': now,
    });
  }

  static Future<void> _touch(Iterable<String> ids) async {
    if (_quiet) return;
    if (_tracking) {
      final now = DateTime.now().millisecondsSinceEpoch;
      var revived = false;
      for (final id in ids) {
        changes[id] = now;
        revived = deleted.remove(id) != null || revived;
      }
      await _settings.put(_changesKey, Map<String, int>.of(changes));
      if (revived) await _settings.put(_deletedKey, Map<String, int>.of(deleted));
    }
    onChanged?.call();
  }

  static Future<void> _removed(Iterable<String> ids) async {
    if (_quiet || ids.isEmpty) return;
    if (_tracking) {
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final id in ids) {
        deleted[id] = now;
        changes.remove(id);
      }
      await _settings.put(_deletedKey, Map<String, int>.of(deleted));
      await _settings.put(_changesKey, Map<String, int>.of(changes));
    }
    onChanged?.call();
  }

  static Future<T> quietly<T>(Future<T> Function() action) =>
      runZoned(action, zoneValues: {_quietZone: true});

  static Future<void> idle() {
    if (_writing == 0) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  static String get deviceId {
    final saved = setting(_deviceKey, '');
    if (saved.isNotEmpty) return saved;
    final random = Random.secure();
    final made = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
    _settings.put(_deviceKey, made);
    return made;
  }

  static Future<T> guardWrites<T>(Future<T> Function() action) async {
    _writing++;
    try {
      return await action();
    } finally {
      _writing--;
      if (_writing == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  static Future<void> init() async {
    if (isMobile) {
      await Hive.initFlutter();
    } else {
      Hive.init((await appDataDir()).path);
    }
    _habits = await Hive.openBox(_habitsBox);
    _habitsStamp = _stampOf(_habits);
    _settings = await Hive.openBox(_settingsBox);
    _changes = null;
    _deleted = null;
    _cleared = null;
    _days = null;
    _categories = await Hive.openBox(_categoriesBox);
    _notes = await Hive.openBox(_notesBox);
    _focus = await Hive.openBox(_focusBox);
    _sleep = await Hive.openBox(_sleepBox);
    final movedFrom = DataLocation.rewriteFrom;
    if (movedFrom != null) await _followMove(movedFrom);
  }

  static Future<void> _followMove(String from) async {
    final to = (await appDataDir()).path;
    for (final box in [
      _habits,
      _settings,
      _categories,
      _notes,
      _focus,
      _sleep,
    ]) {
      for (final key in box.keys.toList()) {
        final value = box.get(key);
        final moved = DataLocation.rewrite(value, from, to);
        if (!identical(moved, value)) await box.put(key, moved);
      }
      await box.flush();
    }
    DataLocation.finish();
  }
  static List<FocusSession> readFocusSessions() {
    final result = <FocusSession>[];
    for (final raw in _focus.values) {
      result.add(FocusSession.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeFocusSession(FocusSession session) async {
    await _focus.put(session.id, session.toMap());
    await _touch([session.id]);
  }

  static FocusSession? focusSession(String id) {
    try {
      final raw = _focus.get(id);
      return raw is Map ? FocusSession.fromMap(Map<String, dynamic>.from(raw)) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeFocusSessions(Iterable<String> ids) async {
    for (final id in ids) {
      await _focus.delete(id);
    }
    await _removed(ids);
  }

  static Future<void> removeFocusFor(String habitId) async {
    final ids = readFocusSessions()
        .where((s) => s.habitId == habitId)
        .map((s) => s.id)
        .toList();
    for (final id in ids) {
      await _focus.delete(id);
    }
    await _removed(ids);
  }

  static List<HabitNote> readNotes() {
    final result = <HabitNote>[];
    for (final raw in _notes.values) {
      result.add(HabitNote.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeNote(HabitNote note) async {
    await _notes.put(note.id, note.toMap());
    await _touch([note.id]);
  }

  static HabitNote? note(String id) {
    try {
      final raw = _notes.get(id);
      return raw is Map ? HabitNote.fromMap(Map<String, dynamic>.from(raw)) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeNote(String id) async {
    await _notes.delete(id);
    await _removed([id]);
  }

  static Future<void> removeNotesFor(String habitId) async {
    final ids = readNotes()
        .where((n) => n.habitId == habitId)
        .map((n) => n.id)
        .toList();
    for (final id in ids) {
      await _notes.delete(id);
    }
    await _removed(ids);
  }

  static Map<String, Habit> readHabits() {
    final result = <String, Habit>{};
    for (final raw in _habits.values) {
      try {
        final habit = Habit.fromJson(raw as String);
        result[habit.id] = habit;
      } catch (e) {
        debugPrint('Skipped an unreadable habit: $e');
      }
    }
    return result;
  }

  static Habit? habit(String id) {
    try {
      final raw = _habits.get(id);
      return raw is String ? Habit.fromJson(raw) : null;
    } catch (_) {
      return null;
    }
  }

  static String? habitName(String id) => habit(id)?.name;

  static Future<void> writeHabit(Habit habit) async {
    await _touchDays(habit);
    await _habits.put(habit.id, habit.toJson());
    _habitsStamp = _stampOf(_habits);
    await _touch([habit.id]);
  }

  static String _stampOf(Box box) {
    final path = box.path;
    if (path == null) return '';
    try {
      final stat = File(path).statSync();
      return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    } catch (_) {
      return '';
    }
  }

  static bool get habitsChangedElsewhere {
    final stamp = _stampOf(_habits);
    return stamp.isEmpty || stamp != _habitsStamp;
  }

  static Future<void> removeHabit(String id) async {
    await _habits.delete(id);
    await _removed([id]);
  }

  static Future<void> reloadHabits() async {
    if (_writing > 0) return;
    if (_habits.isOpen) await _habits.close();
    _habits = await Hive.openBox(_habitsBox);
    _habitsStamp = _stampOf(_habits);
  }

  static List<Category> readCategories() {
    final result = <Category>[];
    for (final raw in _categories.values) {
      try {
        result.add(Category.fromJson(raw as String));
      } catch (e) {
        debugPrint('Skipped an unreadable category: $e');
      }
    }
    return result;
  }

  static Future<void> writeCategory(Category category) =>
      _categories.put(category.id, category.toJson());

  static Future<void> removeCategory(String id) => _categories.delete(id);

  static String categoryKey(String name) => name.trim().toLowerCase();

  static Future<void> mergeCategory(Category category) async {
    final key = categoryKey(category.name);
    final taken = readCategories()
        .any((c) => c.id != category.id && categoryKey(c.name) == key);
    if (!taken) await writeCategory(category);
  }

  static Future<List<Category>> readCategoriesOnce() async {
    final kept = <String, Category>{};
    final all = readCategories()
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    for (final category in all) {
      final key = categoryKey(category.name);
      if (kept.containsKey(key)) {
        await removeCategory(category.id);
      } else {
        kept[key] = category;
      }
    }
    return kept.values.toList();
  }

  static bool get hasCategories => _categories.isNotEmpty;

  static T setting<T>(String key, T fallback) {
    final value = _settings.get(key, defaultValue: fallback);
    return value is T ? value : fallback;
  }

  static Map<String, dynamic> settingMap(String key) {
    final value = _settings.get(key);
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  static Future<void> writeSetting(String key, Object value) =>
      _settings.put(key, value);

  static Map<String, dynamic> readAllSettings() {
    return _settings.toMap().cast<String, dynamic>();
  }

  static Future<void> writeAllSettings(Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      await _settings.put(entry.key, entry.value);
    }
  }

  static Future<void> clearProgress() async {
    final habits = readHabits().values.toList();
    for (final habit in habits) {
      await writeHabit(habit.copyWith(completions: const {}));
    }
    if (_tracking) {
      await stampCleared(
        habits.map((h) => h.id),
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    final gone = [..._notes.keys.cast<String>(), ..._focus.keys.cast<String>()];
    await _notes.clear();
    await _focus.clear();
    await _sleep.clear();
    await _removed(gone);
  }

  // ── Sleep ──────────────────────────────────────────────────────────────────

  static List<SleepEntry> readSleepEntries() {
    final result = <SleepEntry>[];
    for (final raw in _sleep.values) {
      try {
        result.add(
          SleepEntry.fromMap(Map<String, dynamic>.from(raw as Map)),
        );
      } catch (e) {
        debugPrint('Skipped unreadable sleep entry: $e');
      }
    }
    return result;
  }

  static Future<void> writeSleepEntry(SleepEntry entry) =>
      _sleep.put(entry.id, entry.toMap());

  static Future<void> removeSleepEntry(String id) => _sleep.delete(id);

  static Future<void> wipeContent() async {
    await _habits.clear();
    await _notes.clear();
    await _focus.clear();
    await _sleep.clear();
    await _categories.clear();
  }

  static Future<void> wipeEverything() async {
    await wipeContent();
    await _settings.clear();
    _changes = null;
    _deleted = null;
    _cleared = null;
    _days = null;
  }
}
