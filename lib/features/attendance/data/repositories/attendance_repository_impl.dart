import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/features/attendance/domain/models/attendance_model.dart';
import 'package:sum_enterprises/features/attendance/domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final FirebaseFirestore _firestore;

  AttendanceRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<AttendanceModel?> streamTodayAttendance(String employeeId, String date) {
    final docId = '${employeeId}_$date';
    return _firestore
        .collection(AppConstants.collectionAttendance)
        .doc(docId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return AttendanceModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Future<AttendanceModel?> getTodayAttendance(String employeeId, String date) async {
    final docId = '${employeeId}_$date';
    final doc = await _firestore
        .collection(AppConstants.collectionAttendance)
        .doc(docId)
        .get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return AttendanceModel.fromMap(doc.data()!, doc.id);
  }

  @override
  Stream<List<AttendanceModel>> streamEmployeeHistory(String employeeId) {
    return _firestore
        .collection(AppConstants.collectionAttendance)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<List<AttendanceModel>> streamAllAttendance({String? date, String? employeeId}) {
    Query query = _firestore.collection(AppConstants.collectionAttendance);

    if (employeeId != null && employeeId.isNotEmpty) {
      query = query.where('employeeId', isEqualTo: employeeId);
    }
    
    if (date != null && date.isNotEmpty) {
      query = query.where('date', isEqualTo: date);
    } else {
      // Order by default if no compound inequality is blocking it
      query = query.orderBy('createdAt', descending: true);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return AttendanceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // If we filtered by date, firestore compound query constraints might prevent ordering by default without index,
      // so we sort it in-memory to guarantee descending order.
      if (date != null && date.isNotEmpty) {
        list.sort((a, b) {
          final timeA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });
      }
      return list;
    });
  }

  @override
  Future<void> checkIn(AttendanceModel attendance) async {
    final docId = '${attendance.employeeId}_${attendance.date}';
    final docRef = _firestore.collection(AppConstants.collectionAttendance).doc(docId);

    // Run in transaction or simple check to guarantee no duplicates
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      throw Exception('Already checked in for today (${attendance.date}).');
    }

    final data = attendance.toMap();
    await docRef.set(data);
  }

  @override
  Future<void> checkOut(
    String attendanceId,
    DateTime checkOutTime,
    double lat,
    double lng,
    double accuracy,
  ) async {
    final docRef = _firestore.collection(AppConstants.collectionAttendance).doc(attendanceId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw Exception('No attendance record found to check out.');
    }

    final data = snapshot.data();
    if (data != null && data['checkOutTime'] != null) {
      throw Exception('Employee has already checked out for today.');
    }

    await docRef.update({
      'checkOutTime': Timestamp.fromDate(checkOutTime),
      'checkOutLatitude': lat,
      'checkOutLongitude': lng,
      'checkOutAccuracy': accuracy,
      'status': 'Present',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> overrideCheckIn({
    required String employeeId,
    required String employeeName,
    required String date,
    required DateTime checkInTime,
    required String reason,
    required String adminUid,
  }) async {
    final docId = '${employeeId}_$date';
    final docRef = _firestore.collection(AppConstants.collectionAttendance).doc(docId);

    final snapshot = await docRef.get();
    if (snapshot.exists) {
      throw Exception('Employee has already checked in for today ($date).');
    }

    final newRecord = AttendanceModel(
      attendanceId: docId,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date,
      checkInTime: checkInTime,
      status: 'Present',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      source: 'admin',
      overriddenBy: adminUid,
      overrideReason: reason,
      overrideTimestamp: DateTime.now(),
    );

    await docRef.set(newRecord.toMap());
  }

  @override
  Future<void> overrideCheckOut({
    required String attendanceId,
    required DateTime checkOutTime,
    required String reason,
    required String adminUid,
  }) async {
    final docRef = _firestore.collection(AppConstants.collectionAttendance).doc(attendanceId);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw Exception('No attendance record found to check out.');
    }

    final data = snapshot.data();
    if (data != null && data['checkOutTime'] != null) {
      throw Exception('Employee has already checked out for today.');
    }

    await docRef.update({
      'checkOutTime': Timestamp.fromDate(checkOutTime),
      'status': 'Present',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'source': 'admin',
      'overriddenBy': adminUid,
      'overrideReason': reason,
      'overrideTimestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> overrideAttendance({
    required String employeeId,
    required String employeeName,
    required String date,
    required String status,
    required String reason,
    required String adminUid,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) async {
    final docId = '${employeeId}_$date';
    final docRef = _firestore.collection(AppConstants.collectionAttendance).doc(docId);

    final snapshot = await docRef.get();
    final now = DateTime.now();

    final data = {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': date,
      'status': status,
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime) : null,
      'updatedAt': Timestamp.fromDate(now),
      'source': 'admin',
      'overriddenBy': adminUid,
      'overrideReason': reason,
      'overrideTimestamp': Timestamp.fromDate(now),
    };

    if (!snapshot.exists) {
      data['createdAt'] = Timestamp.fromDate(now);
      await docRef.set(data);
    } else {
      await docRef.update(data);
    }
  }
}
