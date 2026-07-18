import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/features/attendance/domain/models/leave_request_model.dart';
import 'package:sum_enterprises/features/attendance/domain/repositories/leave_repository.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  final FirebaseFirestore _firestore;

  LeaveRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<LeaveRequestModel>> streamPendingLeaves() {
    return _firestore
        .collection('leaves')
        .where('status', isEqualTo: 'Pending')
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<List<LeaveRequestModel>> streamEmployeeLeaves(String employeeUid) {
    return _firestore
        .collection('leaves')
        .where('employeeUid', isEqualTo: employeeUid)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LeaveRequestModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<void> applyLeave(LeaveRequestModel leave) async {
    final docRef = _firestore.collection('leaves').doc(leave.leaveId);
    await docRef.set(leave.toMap());
  }

  @override
  Future<void> cancelLeave(String leaveId) async {
    final docRef = _firestore.collection('leaves').doc(leaveId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Leave request not found.');
      }
      
      final data = snapshot.data();
      final status = data?['status'] as String? ?? 'Pending';
      if (status.toLowerCase() != 'pending') {
        throw Exception('Only pending leave requests can be cancelled. Current status: $status.');
      }
      
      transaction.update(docRef, {
        'status': 'Cancelled',
      });
    });
  }

  @override
  Future<void> approveLeave({
    required String leaveId,
    required String adminUid,
    String? adminComment,
  }) async {
    final leaveRef = _firestore.collection('leaves').doc(leaveId);

    await _firestore.runTransaction((transaction) async {
      final leaveSnap = await transaction.get(leaveRef);
      if (!leaveSnap.exists) {
        throw Exception('Leave request not found.');
      }

      final leaveData = leaveSnap.data()!;
      final currentStatus = leaveData['status'] as String? ?? 'Pending';
      if (currentStatus.toLowerCase() != 'pending') {
        throw Exception('Leave request is already processed. Status: $currentStatus.');
      }

      final employeeUid = leaveData['employeeUid'] as String? ?? '';
      if (employeeUid.isEmpty) {
        throw Exception('Leave request does not specify employee ID.');
      }

      // Fetch user details from /users/{uid} to resolve employee name
      final userRef = _firestore.collection(AppConstants.collectionUsers).doc(employeeUid);
      final userSnap = await transaction.get(userRef);
      final employeeName = userSnap.exists
          ? (userSnap.data()?['fullName'] as String? ?? userSnap.data()?['name'] as String? ?? 'Employee')
          : 'Employee';

      final startTimestamp = leaveData['startDate'] as Timestamp;
      final endTimestamp = leaveData['endDate'] as Timestamp;
      final leaveTypeStr = leaveData['type'] as String? ?? 'Full Day';
      final statusValue = leaveTypeStr.toLowerCase() == 'half day' ? 'Half Day' : 'Leave';

      final startDate = startTimestamp.toDate();
      final endDate = endTimestamp.toDate();

      // 1. Update Leave Request Status
      transaction.update(leaveRef, {
        'status': 'Approved',
        'adminComment': adminComment,
        'processedAt': Timestamp.now(),
        'processedBy': adminUid,
      });

      // 2. Loop through every date from startDate to endDate and write/update attendance records
      DateTime current = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(current);
        final attId = '${employeeUid}_$dateStr';
        final attRef = _firestore.collection(AppConstants.collectionAttendance).doc(attId);
        
        final attSnap = await transaction.get(attRef);
        final attendanceData = {
          'employeeId': employeeUid,
          'employeeName': employeeName,
          'date': dateStr,
          'status': statusValue,
          'leaveId': leaveId,
          'updatedAt': Timestamp.now(),
          'source': 'admin',
          'overriddenBy': adminUid,
          'overrideReason': adminComment ?? 'Approved Leave ($leaveTypeStr)',
          'overrideTimestamp': Timestamp.now(),
        };

        if (!attSnap.exists) {
          attendanceData['createdAt'] = Timestamp.now();
          transaction.set(attRef, attendanceData);
        } else {
          transaction.update(attRef, attendanceData);
        }

        current = current.add(const Duration(days: 1));
      }
    });
  }

  @override
  Future<void> rejectLeave({
    required String leaveId,
    required String adminUid,
    String? adminComment,
  }) async {
    final leaveRef = _firestore.collection('leaves').doc(leaveId);

    await _firestore.runTransaction((transaction) async {
      final leaveSnap = await transaction.get(leaveRef);
      if (!leaveSnap.exists) {
        throw Exception('Leave request not found.');
      }

      final leaveData = leaveSnap.data()!;
      final currentStatus = leaveData['status'] as String? ?? 'Pending';
      if (currentStatus.toLowerCase() != 'pending') {
        throw Exception('Leave request is already processed. Status: $currentStatus.');
      }

      transaction.update(leaveRef, {
        'status': 'Rejected',
        'adminComment': adminComment,
        'processedAt': Timestamp.now(),
        'processedBy': adminUid,
      });
    });
  }
}
