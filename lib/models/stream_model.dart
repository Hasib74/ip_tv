import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final bool isHidden;
  final int priority;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.isHidden = false,
    this.priority = 0,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? 'tv',
      isHidden: data['isHidden'] ?? false,
      priority: data['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'isHidden': isHidden,
      'priority': priority,
    };
  }
}

class StreamModel {
  final String id;
  final String title;
  final String subtitle;
  final String categoryId;
  final String logo;
  final String team1Name;
  final String team1Logo;
  final String team2Name;
  final String team2Logo;
  final String streamUrl;
  final DateTime startTime;
  final String status; // 'live', 'upcoming', 'recent'
  final bool isHidden;
  final String subCategory; // 'live_match', 'sports_tv' for sports category
  final bool isScheduled;
  final int priority;
  final String displayStyle; // 'match' or 'simple'
  final String streamType; // 'm3u8', 'webview', 'iframe'
  final int viewerCount;
  final String webSelector; // CSS Selector to keep visible

  StreamModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.categoryId,
    this.logo = '',
    required this.team1Name,
    required this.team1Logo,
    required this.team2Name,
    required this.team2Logo,
    required this.streamUrl,
    required this.startTime,
    required this.status,
    this.isHidden = false,
    this.subCategory = '',
    this.isScheduled = false,
    this.priority = 0,
    this.displayStyle = 'match',
    this.streamType = 'm3u8',
    this.viewerCount = 0,
    this.webSelector = '',
  });

  factory StreamModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return StreamModel(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      categoryId: data['categoryId'] ?? '',
      logo: data['logo'] ?? '',
      team1Name: data['team1Name'] ?? '',
      team1Logo: data['team1Logo'] ?? '',
      team2Name: data['team2Name'] ?? '',
      team2Logo: data['team2Logo'] ?? '',
      streamUrl: data['streamUrl'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'upcoming',
      isHidden: data['isHidden'] ?? false,
      subCategory: data['subCategory'] ?? '',
      isScheduled: data['isScheduled'] ?? false,
      priority: data['priority'] ?? 0,
      displayStyle: data['displayStyle'] ?? 'match',
      streamType: data['streamType'] ?? 'm3u8',
      viewerCount: data['viewerCount'] ?? 0,
      webSelector: data['webSelector'] ?? '',
    );
  }
}
