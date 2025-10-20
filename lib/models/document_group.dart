import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentGroup {
  final String id;
  final String title;
  final DateTime createdAt;
  final int order;

  const DocumentGroup({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.order,
  });

  factory DocumentGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DocumentGroup(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      order: data['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'order': order,
    };
  }

  DocumentGroup copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    int? order,
  }) {
    return DocumentGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
    );
  }
}
