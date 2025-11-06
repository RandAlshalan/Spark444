import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id; // Firestore document ID
  final String role; // 'user' or 'ai'
  final String text; // message content
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
  });

  // Convert Firestore document to ChatMessage
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      role: data['role'] ?? 'user',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convert ChatMessage to map to store in Firestore
  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
