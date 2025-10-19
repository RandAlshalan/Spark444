import 'package:cloud_firestore/cloud_firestore.dart';

class documents {
  final String title;
  final String fileUrl;
  final String groupName;
  final DateTime? createdAt;

  documents({
    required this.title,
    required this.fileUrl,
    required this.groupName,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'fileUrl': fileUrl,
    'groupName': groupName,
    'createdAt': createdAt,
  };

  factory documents.fromMap(Map<String, dynamic> map) => documents(
    title: map['title'],
    fileUrl: map['fileUrl'],
    groupName: map['groupName'],
    createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
  );
}
