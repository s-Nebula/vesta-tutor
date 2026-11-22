import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:vesta_app/l10n/tr.dart';
/// Recurring time slot. [days] uses ISO (1 = Monday … 7 = Sunday) and refers
/// to the day it starts; if [end] < [start] the slot crosses midnight.
///
/// Same logic as `StudySchedule` in Vesta Tracker and
/// `AppBlockerService.StudySchedule` in Kotlin.
class StudySchedule {
  final List<int> days;
  final String start;
  final String end;

  const StudySchedule({
    required this.days,
    required this.start,
    required this.end,
  });

  static int? minutesOf(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  static StudySchedule? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final start = raw['start']?.toString() ?? '';
    final end = raw['end']?.toString() ?? '';
    final days = (raw['days'] is List)
        ? (raw['days'] as List)
            .whereType<num>()
            .map((d) => d.toInt())
            .where((d) => d >= 1 && d <= 7)
            .toSet()
            .toList()
        : <int>[];
    days.sort();

    final s = minutesOf(start);
    final e = minutesOf(end);
    if (s == null || e == null || s == e || days.isEmpty) return null;

    return StudySchedule(days: days, start: start, end: end);
  }

  Map<String, dynamic> toMap() => {'days': days, 'start': start, 'end': end};

  DateTime? activeEnd(DateTime now) {
    final s = minutesOf(start)!;
    final e = minutesOf(end)!;
    final minutes = now.hour * 60 + now.minute;
    final today = DateTime(now.year, now.month, now.day);

    if (e > s) {
      if (days.contains(now.weekday) && minutes >= s && minutes < e) {
        return today.add(Duration(minutes: e));
      }
      return null;
    }

    if (days.contains(now.weekday) && minutes >= s) {
      return today.add(Duration(days: 1, minutes: e));
    }
    final yesterday = now.weekday == 1 ? 7 : now.weekday - 1;
    if (days.contains(yesterday) && minutes < e) {
      return today.add(Duration(minutes: e));
    }
    return null;
  }

  static const _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  String get label {
    final dayText = days.length == 7
        ? tr('Todos los días')
        : (days.length == 5 && days.every((d) => d <= 5))
            ? tr('Lunes a viernes')
            : days.map((d) => _dayLetters[d - 1]).join(' ');
    return '$dayText · $start – $end';
  }
}

/// Documento `children/{childId}/controls/study_mode`.
class StudyModeConfig {
  final bool active;
  final DateTime? endsAt;
  final List<String> allowedApps;
  final List<StudySchedule> schedules;

  const StudyModeConfig({
    this.active = false,
    this.endsAt,
    this.allowedApps = const [],
    this.schedules = const [],
  });

  factory StudyModeConfig.fromDoc(Map<String, dynamic>? data) {
    if (data == null) return const StudyModeConfig();
    final endsAt = data['endsAt'];
    return StudyModeConfig(
      active: data['active'] == true,
      endsAt: endsAt is Timestamp ? endsAt.toDate() : null,
      allowedApps: (data['allowedApps'] is List)
          ? (data['allowedApps'] as List).map((e) => e.toString()).toList()
          : const [],
      schedules: (data['schedules'] is List)
          ? (data['schedules'] as List)
              .map(StudySchedule.fromMap)
              .whereType<StudySchedule>()
              .toList()
          : const [],
    );
  }

  bool _manualActiveAt(DateTime now) =>
      active && (endsAt == null || now.isBefore(endsAt!));

  bool isActiveAt(DateTime now) =>
      _manualActiveAt(now) || schedules.any((s) => s.activeEnd(now) != null);

  DateTime? currentEnd(DateTime now) {
    final ends = <DateTime>[];
    if (_manualActiveAt(now)) {
      if (endsAt == null) return null;
      ends.add(endsAt!);
    }
    for (final schedule in schedules) {
      final end = schedule.activeEnd(now);
      if (end != null) ends.add(end);
    }
    if (ends.isEmpty) return null;
    ends.sort();
    return ends.last;
  }

  StudyModeConfig copyWith({
    bool? active,
    DateTime? endsAt,
    bool clearEndsAt = false,
    List<String>? allowedApps,
    List<StudySchedule>? schedules,
  }) {
    return StudyModeConfig(
      active: active ?? this.active,
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      allowedApps: allowedApps ?? this.allowedApps,
      schedules: schedules ?? this.schedules,
    );
  }

  /// Format validated by `validStudyMode` in the Firestore rules.
  Map<String, dynamic> toDoc() => {
        'active': active,
        'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt!),
        'allowedApps': allowedApps.take(100).toList(),
        'schedules': schedules.take(7).map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      };

  static DocumentReference<Map<String, dynamic>> ref(String childId) =>
      FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .collection('controls')
          .doc('study_mode');

  Future<void> save(String childId) => ref(childId).set(toDoc());
}
