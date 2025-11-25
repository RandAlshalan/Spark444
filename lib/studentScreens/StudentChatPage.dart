import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';

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

  Future<void> _autoSpeak(String base64Audio) async {
    // تنظيف النص من أي مسافات أو أسطر جديدة قد تسبب مشاكل
    String cleanBase64 = base64Audio.replaceAll('\n', '').trim();
    
    if (cleanBase64.isEmpty) return;

    try {
      // 3. ✅ إضافة حماية (Try-Catch)
      final bytes = base64Decode(cleanBase64);

      // إيقاف أي صوت سابق قبل البدء
      await _player.stop();
      
      _startLip();
      await _player.play(BytesSource(bytes));
      
    } catch (e) {
      debugPrint("❌ Error playing audio: $e");
      _stopLip(); // تأكد من إيقاف الفم إذا فشل الصوت
    }
  }

  // --------------------
  // إرسال الرسالة
  // --------------------

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _controller.clear();
      _isLoading = true;
    });

    final history = _messages.toList();

    try {
      final res = await _chatService.sendMessage(history);

      final reply = res["reply"] ?? "";
      final audio = res["audio"] ?? "";

      setState(() {
        _messages.add({"role": "ai", "text": reply});
      });

      if (audio.isNotEmpty) {
        _autoSpeak(audio);
      }
    } catch (e) {
       // إضافة معالجة خطأ للشبكة
       debugPrint("Network Error: $e");
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Error: $e")),
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
        title: const Text("AI Interview Coach"),
        backgroundColor: _primaryColor,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          Center(
            child: Image.asset(
              _mouthOpen
                  ? "assets/sparkie_open.png"
                  : "assets/sparkie_closed.png",
              height: 160,
            ),
          ),

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

          _inputBox(),
        ],
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