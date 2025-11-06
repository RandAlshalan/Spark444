import 'dart:convert'; // For jsonEncode, utf8, and jsonDecode
import 'dart:async'; // For TimeoutException and Duration
import 'package:http/http.dart' as http;

class ChatService {
  final String baseUrl = 'https://spark444-ai.onrender.com'; // Your URL

  // --- The most important change: Accept a List of messages instead of a String ---
  Future<String> sendMessage(
    List<Map<String, String>> messages, { // Now accepts a List
    String? resumeId,
    String? trainingType,
  }) async {
    try {
      // Build the request body
      final requestBody = {
        'messages': messages, // Send the full history
        // These keys will only be added if the value is not null
        if (resumeId != null) 'resumeId': resumeId,
        if (trainingType != null) 'trainingType': trainingType,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody), // Send the new body
          )
          .timeout(const Duration(seconds: 20)); // Add a timeout

      if (response.statusCode == 200) {
        // Handle non-English characters in the response
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['reply'] ?? 'No response';
      } else {
        // Try to read the error message from the server
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMessage = data['error'] ?? 'Unknown error';
        throw Exception(
            'Failed to get AI reply: ${response.statusCode} ($errorMessage)');
      }
    } on TimeoutException {
      // Handle network timeout
      throw Exception('The connection timed out. Please try again.');
    } catch (e) {
      // Handle other errors (like no internet, or parsing errors)
      throw Exception('An unknown error occurred: ${e.toString()}');
    }
  }
}