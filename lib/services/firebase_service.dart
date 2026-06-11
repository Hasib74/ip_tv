import 'dart:convert';
import 'package:http/http.dart' as http;
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

  // Get all categories and filter/sort in code to avoid composite index errors
  Stream<List<CategoryModel>> getCategories({bool includeHidden = true}) {
    return _db.collection('categories').snapshots().map((snapshot) {
      List<CategoryModel> cats = snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      
      if (!includeHidden) {
        cats = cats.where((c) => !c.isHidden).toList();
      }
      
      // Sort by priority in memory
      cats.sort((a, b) => a.priority.compareTo(b.priority));
      return cats;
    });
  }

  // Add/Update category
  Future<void> saveCategory(String id, Map<String, dynamic> data) async {
    await _db.collection('categories').doc(id).set(data, SetOptions(merge: true));
  }

  // Delete category
  Future<void> deleteCategory(String id) async {
    await _db.collection('categories').doc(id).delete();
  }

  // Get streams and filter in code to avoid index requirement
  Stream<List<StreamModel>> getStreams({String? categoryId, bool includeHidden = true}) {
    Query query = _db.collection('streams');

    if (categoryId != null && categoryId != 'all') {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.snapshots().map((snapshot) {
      List<StreamModel> streams = snapshot.docs.map((doc) => StreamModel.fromFirestore(doc)).toList();
      
      if (!includeHidden) {
        streams = streams.where((s) => !s.isHidden).toList();
      }
      
      // Sort by priority (Serial)
      streams.sort((a, b) => a.priority.compareTo(b.priority));
      return streams;
    });
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

  // Schedule a notification
  Future<void> scheduleNotification(String title, String body, DateTime time) async {
    await _db.collection('scheduled_notifications').add({
      'title': title,
      'body': body,
      'scheduledTime': Timestamp.fromDate(time),
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });
  }

  // Get all scheduled notifications
  Stream<QuerySnapshot> getScheduledNotifications() {
    return _db.collection('scheduled_notifications')
        .orderBy('scheduledTime', descending: false)
        .snapshots();
  }

  // Delete scheduled notification
  Future<void> deleteScheduledNotification(String id) async {
    await _db.collection('scheduled_notifications').doc(id).delete();
  }

  // Save M3U URL history
  Future<void> saveM3uUrl(String url) async {
    if (url.isEmpty) return;
    final id = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await _db.collection('m3u_history').doc(id).set({
      'url': url,
      'lastUsed': Timestamp.now(),
    });
  }

  // Get M3U URL history
  Stream<List<String>> getM3uHistory() {
    return _db.collection('m3u_history')
        .orderBy('lastUsed', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()['url'] as String).toList());
  }

  // Send FCM Notification (Topic based)
  Future<void> sendBroadcastNotification(String title, String body) async {
    const String serverKey = 'YOUR_FCM_SERVER_KEY_HERE'; // User needs to provide this
    
    final data = {
      "to": "/topics/all_users",
      "notification": {
        "title": title,
        "body": body,
        "sound": "default",
      },
      "data": {
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "id": "1",
        "status": "done",
      }
    };

    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: json.encode(data),
      );
    } catch (e) {
      debugPrint("Error sending FCM: $e");
      rethrow;
    }
  }
}
