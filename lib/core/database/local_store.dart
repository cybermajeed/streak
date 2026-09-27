import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_ce_flutter/hive_flutter.dart';
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

  static late Box _habits;
  static late Box _settings;
  static late Box _categories;
  static late Box _notes;
  static late Box _focus;
  static late Box _sleep;

  static int _writing = 0;

  static bool get isWriting => _writing > 0;

  static Future<T> guardWrites<T>(Future<T> Function() action) async {
    _writing++;
    try {
      return await action();
    } finally {
      _writing--;
    }
  }

  static Future<void> init() async {
    if (isMobile) {
      await Hive.initFlutter();
    } else {
      Hive.init((await appDataDir()).path);
    }
    _habits = await Hive.openBox(_habitsBox);
    _settings = await Hive.openBox(_settingsBox);
    _categories = await Hive.openBox(_categoriesBox);
    _notes = await Hive.openBox(_notesBox);
    _focus = await Hive.openBox(_focusBox);
    _sleep = await Hive.openBox(_sleepBox);
  }

  static List<FocusSession> readFocusSessions() {
    final result = <FocusSession>[];
    for (final raw in _focus.values) {
      result.add(FocusSession.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeFocusSession(FocusSession session) =>
      _focus.put(session.id, session.toMap());

  static Future<void> removeFocusSessions(Iterable<String> ids) async {
    for (final id in ids) {
      await _focus.delete(id);
    }
  }

  static Future<void> removeFocusFor(String habitId) async {
    final ids = readFocusSessions()
        .where((s) => s.habitId == habitId)
        .map((s) => s.id)
        .toList();
    for (final id in ids) {
      await _focus.delete(id);
    }
  }

  static List<HabitNote> readNotes() {
    final result = <HabitNote>[];
    for (final raw in _notes.values) {
      result.add(HabitNote.fromMap(Map<String, dynamic>.from(raw as Map)));
    }
    return result;
  }

  static Future<void> writeNote(HabitNote note) =>
      _notes.put(note.id, note.toMap());

  static Future<void> removeNote(String id) => _notes.delete(id);

  static Future<void> removeNotesFor(String habitId) async {
    final ids = readNotes()
        .where((n) => n.habitId == habitId)
        .map((n) => n.id)
        .toList();
    for (final id in ids) {
      await _notes.delete(id);
    }
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

  static Future<void> writeHabit(Habit habit) =>
      _habits.put(habit.id, habit.toJson());

  static Future<void> removeHabit(String id) => _habits.delete(id);

  static Future<void> reloadHabits() async {
    if (_writing > 0) return;
    if (_habits.isOpen) await _habits.close();
    _habits = await Hive.openBox(_habitsBox);
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
    for (final habit in readHabits().values) {
      await writeHabit(habit.copyWith(completions: const {}));
    }
    await _notes.clear();
    await _focus.clear();
    await _sleep.clear();
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
    await _categories.clear();
  }

  static Future<void> wipeEverything() async {
    await wipeContent();
    await _settings.clear();
  }
}
