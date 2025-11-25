import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // تأكد أن الرابط هو رابط سيرفرك الصحيح
  final String baseUrl = 'https://spark444-ai.onrender.com';

  Future<Map<String, dynamic>> sendMessage(
    List<Map<String, String>> messages, {
    String? resumeId,
    String? trainingType,
  }) async {
    try {
      final body = {
        'messages': messages,
        if (resumeId != null) 'resumeId': resumeId,
        if (trainingType != null) 'trainingType': trainingType,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // 1. فك تشفير الرد لدعم اللغة العربية
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      // 2. التحقق من حالة السيرفر
      if (response.statusCode == 200) {
        return {
          "reply": data['reply'] ?? "No response", // حماية من القيم الفارغة
          "audio": data['audio'] ?? "",            // حماية من القيم الفارغة
          "mimeType": data['mimeType'] ?? "",
        };
      } else {
        // إذا كان هناك خطأ من السيرفر (مثلاً مفتاح OpenAI غير صحيح أو انتهى الرصيد)
        throw Exception(data['error'] ?? "Server Error: ${response.statusCode}");
      }
    } catch (e) {
      // إعادة رمي الخطأ ليظهر في واجهة المستخدم (UI)
      throw Exception("Failed to connect: $e");
    }
  }
}