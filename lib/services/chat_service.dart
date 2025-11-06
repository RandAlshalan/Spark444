import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String baseUrl = 'https://spark444-ai.onrender.com'; 

  Future<String> sendMessage(String message, {String? profileInfo}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': 'Student profile: $profileInfo\nUser message: $message',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reply'] ?? 'No response';
    } else {
      throw Exception('Failed to get AI reply');
    }
  }
}
