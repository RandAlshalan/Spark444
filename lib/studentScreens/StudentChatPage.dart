import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import 'dart:io'; // للتعامل مع الملفات
import 'package:path_provider/path_provider.dart'; // للوصول للملفات المؤقتة

const Color _primaryColor = Color(0xFF422F5D);
const Color _aiBubbleColor = Color(0xFFF1F1F1);
const Color _scaffoldBgColor = Color(0xFFF8F9FA);

class StudentChatPage extends StatefulWidget {
  const StudentChatPage({super.key});

  @override
  State<StudentChatPage> createState() => _StudentChatPageState();
}

class _StudentChatPageState extends State<StudentChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // 🔊 Player
  final AudioPlayer _player = AudioPlayer();

  // Lip Sync
  Timer? _lipTimer;
  bool _mouthOpen = false;

  @override
  void initState() {
    super.initState();

    const welcome = "Hi! I'm your AI Interview Coach. 👋";
    _messages.add({"role": "ai", "text": welcome});

    // 1. ⚠️ تم حذف سطر _autoSpeak(welcome) لأنه يسبب كراش
    // النص العادي لا يمكن تحويله لـ Base64

    // 2. ✅ إعداد مستمع انتهاء الصوت مرة واحدة هنا
    _player.onPlayerComplete.listen((_) {
      _stopLip();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lipTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  // --------------------
  // Lip Sync
  // --------------------

  void _startLip() {
    _lipTimer?.cancel();
    _lipTimer = Timer.periodic(const Duration(milliseconds: 160), (_) {
      setState(() => _mouthOpen = !_mouthOpen);
    });
  }

  void _stopLip() {
    _lipTimer?.cancel();
    setState(() => _mouthOpen = false);
  }

  // --------------------
  // تشغيل صوت من Base64
  // --------------------
// --------------------
  // تشغيل الصوت (الحل النهائي للأيفون والأندرويد)
  // --------------------
  Future<void> _autoSpeak(String base64Audio) async {
    // 1. تنظيف النص من أي شوائب
    String cleanBase64 = base64Audio.replaceAll('\n', '').replaceAll('\r', '').trim();
    
    if (cleanBase64.isEmpty) {
      debugPrint("⚠️ Audio string is empty");
      return;
    }

    try {
      // 2. تحويل النص إلى بايتات
      final bytes = base64Decode(cleanBase64);

      // 3. الحصول على المجلد المؤقت في الهاتف
      final dir = await getTemporaryDirectory();
      
      // 4. إنشاء ملف بامتداد mp3 (ضروري جداً للأيفون)
      final file = File('${dir.path}/ai_voice.mp3');

      // 5. كتابة الصوت داخل الملف
      await file.writeAsBytes(bytes);

      // 6. إعداد حركة الشفاه
      _startLip();
      await _player.stop(); // إيقاف أي صوت سابق

      // 7. التشغيل من الملف (هذا يحل مشكلة DarwinAudioError)
      await _player.play(DeviceFileSource(file.path));

    } catch (e) {
      debugPrint("❌ Error playing audio: $e");
      _stopLip();
    }
  }

  // --------------------
  // إرسال الرسالة
  // --------------------
Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _messages.add({"role": "user", "text": text});
      _controller.clear();
      _isLoading = true;
    });

    try {
      print("🚀 Sending message to server..."); // طباعة للتأكد من الإرسال
      final res = await _chatService.sendMessage(_messages);

      final reply = res["reply"] ?? "";
      final audio = res["audio"] ?? ""; // الصوت المشفر

      print("✅ Reply received: $reply");
      print("🔊 Audio length received: ${audio.length}"); // كم حجم الصوت الواصل؟

      setState(() {
        _messages.add({"role": "ai", "text": reply});
      });

      if (audio.isNotEmpty) {
        print("▶️ Attempting to play audio...");
        await _autoSpeak(audio);
      } else {
        print("⚠️ Warning: Audio string is empty!");
      }

    } catch (e) {
      print("❌ ERROR: $e"); // هنا سيظهر لك سبب الخطأ الحقيقي
      
      // إظهار رسالة خطأ في الشاشة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollDown();
      }
    }
  }

  // Scroll
  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --------------------
  // UI
  // --------------------
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor,
      appBar: AppBar(
        title: const Text(
          "AI Interview Coach",
          style: TextStyle(color: Colors.white), // 👈 هنا جعلنا الخط أبيض
        ),
        backgroundColor: _primaryColor,
        // 👇 هذا السطر إضافي ومهم: يجعل زر "الرجوع" (السهم) أبيض أيضاً إذا كان موجوداً
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // 👇 هنا بداية GestureDetector لإخفاء الكيبورد عند اللمس
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        // 👇 هنا يبدأ العامود (Column) كما كان سابقاً
        child: Column(
          children: [
            const SizedBox(height: 10),

            // صورة الروبوت
            Center(
              child: Image.asset(
                _mouthOpen
                    ? "assets/sparkie_open.png"
                    : "assets/sparkie_closed.png",
                height: 160,
              ),
            ),

            // قائمة الرسائل
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  final isUser = msg["role"] == "user";

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? _primaryColor : _aiBubbleColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: msg["role"] == "ai"
                          ? MarkdownBody(data: msg["text"]!)
                          : Text(
                              msg["text"]!,
                              style: const TextStyle(color: Colors.white),
                            ),
                    ),
                  );
                },
              ),
            ),

            // مربع الإدخال
            _inputBox(),
          ],
        ),
      ),
    );
  }
  Widget _inputBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: _primaryColor,
            child: IconButton(
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          )
        ],
      ),
    );
  }
}