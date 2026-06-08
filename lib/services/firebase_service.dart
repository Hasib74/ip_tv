import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/stream_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save/Update Device Token for Push Notifications
  Future<void> saveDeviceToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('user_tokens').doc(token).set({
          'token': token,
          'platform': defaultTargetPlatform.toString(),
          'lastActive': Timestamp.now(),
        });
      }
    } catch (e) {
      debugPrint("Error saving device token: $e");
    }
  }

  // Get all user tokens for broadcasting
  Future<List<String>> getAllUserTokens() async {
    final snapshot = await _db.collection('user_tokens').get();
    return snapshot.docs.map((doc) => doc.data()['token'] as String).toList();
  }

  // Get App Version Config
  Future<Map<String, dynamic>?> getAppVersionConfig() async {
    final doc = await _db.collection('admin_config').doc('app_version').get();
    return doc.data();
  }

  // Update App Version Config
  Future<void> updateAppVersionConfig(String version, int buildNumber, String downloadUrl) async {
    await _db.collection('admin_config').doc('app_version').set({
      'latest_version': version,
      'latest_build_number': buildNumber,
      'download_url': downloadUrl,
      'updatedAt': Timestamp.now(),
    });
  }

  // ... (rest of the existing methods)

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
