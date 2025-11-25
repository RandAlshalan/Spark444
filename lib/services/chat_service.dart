import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ChatReply {
  final String text;
  final Uint8List? audioBytes;

  ChatReply({required this.text, this.audioBytes});
}

class ChatService {
  final String baseUrl = 'https://spark444-ai.onrender.com'; // عدّل لو عندك دومين آخر

  Future<ChatReply> sendMessage(
    List<Map<String, String>> messages, {
    String? resumeId,
    String? trainingType,
  }) async {
    try {
      final requestBody = {
        'messages': messages,
        if (resumeId != null) 'resumeId': resumeId,
        if (trainingType != null) 'trainingType': trainingType,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      final body = utf8.decode(response.bodyBytes);
      final data = jsonDecode(body);

      if (response.statusCode == 200) {
        final text = data['reply'] ?? 'No response';
        Uint8List? audioBytes;
        if (data['audio'] != null) {
          audioBytes = base64Decode(data['audio']);
        }
        return ChatReply(text: text, audioBytes: audioBytes);
      } else {
        final errorMessage = data['error'] ?? 'Unknown error';
        throw Exception(
            'Failed to get AI reply: ${response.statusCode} ($errorMessage)');
      }
    } on TimeoutException {
      throw Exception('The connection timed out. Please try again.');
    } catch (e) {
      throw Exception('An unknown error occurred: ${e.toString()}');
    }
  }
}
