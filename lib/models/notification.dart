import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId; // Student ID who receives this notification
  final String type; // 'new_opportunity', 'application_update', 'review_reply', etc.
  final String title;
  final String body;
  final Map<String, dynamic>? data; // Additional data (companyId, opportunityId, etc.)
  final bool read;
  final Timestamp createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? data['receiverId'] ?? '',
      type: data['type'] ?? 'general',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: data['data'] as Map<String, dynamic>?,
      read: data['read'] ?? false,
      createdAt: data['createdAt'] as Timestamp? ??
          data['timestamp'] as Timestamp? ??
          Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
      'read': read,
      'createdAt': createdAt,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? read,
    Timestamp? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
