import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stream_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get all categories
  Stream<List<CategoryModel>> getCategories() {
    return _db.collection('categories').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList());
  }

  // Get streams by category
  Stream<List<StreamModel>> getStreams({String? categoryId}) {
    // query simple রাখা হয়েছে যাতে composite index এরর না দেয়
    Query query = _db.collection('streams');

    if (categoryId != null && categoryId != 'all') {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => StreamModel.fromFirestore(doc)).toList());
  }

  // Delete a stream
  Future<void> deleteStream(String id) async {
    await _db.collection('streams').doc(id).delete();
  }

  // Update a stream
  Future<void> updateStream(String id, Map<String, dynamic> data) async {
    await _db.collection('streams').doc(id).update(data);
  }

  // Verify Admin Credentials
  Future<bool> verifyAdmin(String id, String password) async {
    try {
      final doc = await _db.collection('admin_config').doc('credentials').get();
      if (doc.exists) {
        return doc.data()?['id'] == id && doc.data()?['password'] == password;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
