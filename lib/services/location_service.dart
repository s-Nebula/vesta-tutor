import 'package:cloud_firestore/cloud_firestore.dart';

class TutorLocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>?> obtenerUbicacionHijoStream(
    String tutorId,
    String childId,
  ) {
    return _db
        .collection('telemetria')
        .doc(childId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      return snapshot.data();
    });
  }
}
