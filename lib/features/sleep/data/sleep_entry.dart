import 'package:streak/core/extensions/date_extensions.dart';
import 'package:uuid/uuid.dart';

class SleepEntry {
  SleepEntry({
    required this.id,
    required this.bedTime,
    required this.wakeTime,
  });

  factory SleepEntry.create({
    required DateTime bedTime,
    required DateTime wakeTime,
  }) =>
      SleepEntry(
        id: const Uuid().v4(),
        bedTime: bedTime,
        wakeTime: wakeTime,
      );

  final String id;
  final DateTime bedTime;
  final DateTime wakeTime;

  Duration get duration => wakeTime.difference(bedTime);

  double get hours => duration.inMinutes / 60.0;

  /// The calendar day this sleep session belongs to = the wake-up day.
  String get dayKey => wakeTime.atMidnight.dayKey;

  DateTime get wakeDay => wakeTime.atMidnight;

  Map<String, dynamic> toMap() => {
        'id': id,
        'bedTime': bedTime.toIso8601String(),
        'wakeTime': wakeTime.toIso8601String(),
      };

  factory SleepEntry.fromMap(Map<String, dynamic> map) => SleepEntry(
        id: map['id'] as String,
        bedTime: DateTime.parse(map['bedTime'] as String),
        wakeTime: DateTime.parse(map['wakeTime'] as String),
      );
}
