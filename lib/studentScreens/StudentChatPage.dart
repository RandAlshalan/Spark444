import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

  final AudioPlayer _player = AudioPlayer();
  Timer? _lipTimer;
  bool _mouthOpen = false;

  @override
  void initState() {
    super.initState();
    const welcome = "Hi! I'm your AI Interview Coach. 👋";
    _messages.add({"role": "ai", "text": welcome});

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
  // Lip Sync Logic
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
  // Audio Playback
  // --------------------
  Future<void> _autoSpeak(String base64Audio) async {
    String cleanBase64 = base64Audio.replaceAll('\n', '').replaceAll('\r', '').trim();
    if (cleanBase64.isEmpty) return;

    try {
      final bytes = base64Decode(cleanBase64);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ai_voice.mp3');
      await file.writeAsBytes(bytes);

      _startLip();
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint("❌ Error playing audio: $e");
      _stopLip();
    }
  }

  // --------------------
  // Send Message
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
      final res = await _chatService.sendMessage(_messages);
      final reply = res["reply"] ?? "";
      final audio = res["audio"] ?? "";

      setState(() {
        _messages.add({"role": "ai", "text": reply});
      });

      if (audio.isNotEmpty) {
        await _autoSpeak(audio);
      }
    } catch (e) {
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
  // 🔥 دالة التعامل مع زر الرجوع 🔥
  // --------------------
  Future<bool> _onWillPop() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Warning ⚠️'),
            content: const Text('If you go back, the chat history will be deleted. Are you sure?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // لا تخرج
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // اخرج
                child: const Text(
                  'Exit',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        )) ??
        false; // إذا ضغط خارج الصندوق لا تخرج
  }

  // --------------------
  // UI
  // --------------------
  @override
  Widget build(BuildContext context) {
    // 👇 تم إحاطة Scaffold بـ WillPopScope
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _scaffoldBgColor,
        appBar: AppBar(
          title: const Text(
            "AI Interview Coach",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Robot Image
              Center(
                child: Image.asset(
                  _mouthOpen
                      ? "assets/sparkie_open.png"
                      : "assets/sparkie_closed.png",
                  height: 160,
                ),
              ),

              // Chat List
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

              // Input Box
              _inputBox(),
            ],
          ),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          )
        ],
      ),
    );
  }
}
