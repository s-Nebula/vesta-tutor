import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Seen until" mark per minor, stored on this phone.
///
/// Firestore rules don't allow alerts to be modified (only created by the
/// device and deleted by the guardian), so read state is local and needs no
/// new write permissions.
class AlertReadState {
  AlertReadState._();

  static final StreamController<String> _changes =
      StreamController<String>.broadcast();

  static String _key(String childId) => 'alerts_seen_at_$childId';

  static Future<DateTime?> lastSeen(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key(childId));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> markAllSeen(String childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(childId), DateTime.now().millisecondsSinceEpoch);
    _changes.add(childId);
  }

  /// Event date: the device's if present (survives offline periods),
  /// otherwise the server's.
  static DateTime? alertDate(Map<String, dynamic> data) {
    final occurred = data['occurredAt'];
    if (occurred is Timestamp) return occurred.toDate();
    final server = data['timestamp'];
    if (server is Timestamp) return server.toDate();
    return null;
  }

  static bool isUnread(Map<String, dynamic> data, DateTime? seenAt) {
    if (seenAt == null) return true;
    final server = data['timestamp'];
    // Compared with the time it reached the server: an alert generated offline
    // and synced later also counts as new.
    final arrived = server is Timestamp ? server.toDate() : alertDate(data);
    return arrived == null || arrived.isAfter(seenAt);
  }

  /// Number of unseen alerts (out of the 100 most recent).
  static Stream<int> unreadCountStream(String childId) {
    late StreamController<int> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? alertsSub;
    StreamSubscription<String>? changesSub;
    List<Map<String, dynamic>> latest = const [];

    Future<void> emit() async {
      final seen = await lastSeen(childId);
      if (controller.isClosed) return;
      controller.add(latest.where((data) => isUnread(data, seen)).length);
    }

    controller = StreamController<int>(
      onListen: () {
        alertsSub = FirebaseFirestore.instance
            .collection('children')
            .doc(childId)
            .collection('alerts')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots()
            .listen(
          (snapshot) {
            latest = snapshot.docs.map((doc) => doc.data()).toList();
            unawaited(emit());
          },
          // No permission for alerts: there is simply no counter.
          onError: (_) => controller.add(0),
        );
        changesSub = _changes.stream
            .where((id) => id == childId)
            .listen((_) => unawaited(emit()));
      },
      onCancel: () async {
        await alertsSub?.cancel();
        await changesSub?.cancel();
      },
    );

    return controller.stream;
  }
}
