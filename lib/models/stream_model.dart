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
  final String team1Name;
  final String team1Logo;
  final String team2Name;
  final String team2Logo;
  final String streamUrl;
  final DateTime startTime;
  final String status; // 'live', 'upcoming', 'recent'
  final bool isHidden;

  StreamModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.categoryId,
    required this.team1Name,
    required this.team1Logo,
    required this.team2Name,
    required this.team2Logo,
    required this.streamUrl,
    required this.startTime,
    required this.status,
    this.isHidden = false,
  });

  factory StreamModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return StreamModel(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      categoryId: data['categoryId'] ?? '',
      team1Name: data['team1Name'] ?? '',
      team1Logo: data['team1Logo'] ?? '',
      team2Name: data['team2Name'] ?? '',
      team2Logo: data['team2Logo'] ?? '',
      streamUrl: data['streamUrl'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'upcoming',
      isHidden: data['isHidden'] ?? false,
    );
  }
}
