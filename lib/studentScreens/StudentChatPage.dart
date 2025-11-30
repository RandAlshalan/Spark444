import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

const Color _scaffoldBgColor = Color(0xFFF8F9FA);
const Color _userBubbleColor = Color(0xFFE0E0E0); // Light grey for user messages

// Gradient colors matching the header
const LinearGradient _aiGradient = LinearGradient(
  colors: [Color(0xFFD54DB9), Color(0xFF8D52CC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

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
  bool _isMuted = false;

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

      if (audio.isNotEmpty && !_isMuted) {
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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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
          actions: [
            IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              tooltip: _isMuted ? 'Unmute AI' : 'Mute AI',
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                  if (_isMuted) {
                    _player.stop();
                    _stopLip();
                  }
                });
              },
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Robot Image
              Center(
                child: Image.asset(
                  _mouthOpen
                      ? "assets/sparkie_open.png"
                      : "assets/sparkie_closed.png",
                  height: 140,
                ),
              ),

              const SizedBox(height: 4),

              // Chat List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final msg = _messages[i];
                    final isUser = msg["role"] == "user";

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          gradient: isUser ? null : _aiGradient,
                          color: isUser ? _userBubbleColor : null,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
                            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: msg["role"] == "ai"
                            ? MarkdownBody(
                                data: msg["text"]!,
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(color: Colors.white, fontSize: 15),
                                  strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                                  code: TextStyle(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    color: Colors.white,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              )
                            : Text(
                                msg["text"]!,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: _aiGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD54DB9).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
