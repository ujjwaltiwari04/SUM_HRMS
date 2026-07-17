import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sum_enterprises/core/constants/app_constants.dart';
import 'package:sum_enterprises/features/location/domain/models/location_model.dart';
import 'package:sum_enterprises/features/location/domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  final FirebaseFirestore _firestore;

  LocationRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveLocationUpdate(LocationModel location) async {
    final Map<String, dynamic> data = location.toMap();

    // 1. Save new historical location document
    await _firestore
        .collection(AppConstants.collectionEmployeeLocations)
        .add(data);

    // 2. Maintain latest known location in separate collection for fast dashboard loading
    await _firestore
        .collection(AppConstants.collectionEmployeeLastLocation)
        .doc(location.employeeId)
        .set(data);
  }

  @override
  Stream<LocationModel?> streamLastLocation(String employeeId) {
    return _firestore
        .collection(AppConstants.collectionEmployeeLastLocation)
        .doc(employeeId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return LocationModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  @override
  Stream<List<LocationModel>> streamAllLastLocations() {
    return _firestore
        .collection(AppConstants.collectionEmployeeLastLocation)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LocationModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<List<LocationModel>> streamLocationHistory({String? employeeId, String? date}) {
    Query query = _firestore.collection(AppConstants.collectionEmployeeLocations);

    if (employeeId != null && employeeId.isNotEmpty) {
      query = query.where('employeeId', isEqualTo: employeeId);
    }

    if (date != null && date.isNotEmpty) {
      try {
        final parsedDate = DateFormat('yyyy-MM-dd').parse(date);
        final startOfDay = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 0, 0, 0);
        final endOfDay = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 23, 59, 59, 999);

        query = query
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      } catch (e) {
        // Fallback if parsing fails
      }
    }

    // Attempt firestore sorting, and always apply client-side sorting as robust fallback
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return LocationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Guarantee descending sorting by timestamp (newest first)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  @override
  Future<void> cleanOldLocationHistory(int daysOlderThan) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOlderThan));
    
    final snapshot = await _firestore
        .collection(AppConstants.collectionEmployeeLocations)
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    if (snapshot.docs.isEmpty) return;

    final writeBatch = _firestore.batch();
    for (final doc in snapshot.docs) {
      writeBatch.delete(doc.reference);
    }
    await writeBatch.commit();
  }
}
