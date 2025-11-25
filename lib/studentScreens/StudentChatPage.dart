import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/chat_service.dart';

// --- إعدادات عامة ---
const Color _primaryColor = Color(0xFF422F5D);
const Color _aiBubbleColor = Color(0xFFF1F1F1);
const Color _scaffoldBgColor = Color(0xFFF8F9FA);

class StudentChatPage extends StatefulWidget {
  const StudentChatPage({super.key});

  @override
  State<StudentChatPage> createState() => _StudentChatPageState();
}

class _StudentChatPageState extends State<StudentChatPage> {
  // Controllers
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Service
  final ChatService _chatService = ChatService();

  // Messages
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // Lip Sync
  bool _mouthOpen = false;
  Timer? _lipSyncTimer;

  // Audio Player
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    // رسالة ترحيب نصية فقط (بدون صوت من السيرفر)
    const welcomeText =
        "Hi! I'm your AI Interview Coach. 👋\n\nAsk me any question to prepare for your interview.";

    _messages.add({
      'role': 'ai',
      'text': welcomeText,
    });

    // لما ينتهي الصوت، نوقف تحريك الفم
    _audioPlayer.onPlayerComplete.listen((event) {
      _stopLipSync();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _stopLipSync();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ---------------- LIP SYNC -----------------
  void _startLipSync() {
    _lipSyncTimer?.cancel();
    _lipSyncTimer = Timer.periodic(
      const Duration(milliseconds: 180),
      (_) {
        if (!mounted) return;
        setState(() {
          _mouthOpen = !_mouthOpen;
        });
      },
    );
  }

  void _stopLipSync() {
    _lipSyncTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _mouthOpen = false;
    });
  }

  // ---------------- SCROLL -------------------
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------- PLAY AUDIO --------------
  Future<void> _playAudio(Uint8List audioBytes) async {
    _startLipSync();
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(audioBytes));
  }

  // ---------------- SEND MESSAGE ------------
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final String? currentResumeId = 'resume_12345'; // عدّلها من حالتك
    final String? currentTrainingType = 'Software Development';

    final userMessage = {'role': 'user', 'text': text};

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    // history بدون رسالة الترحيب
    final history = _messages.where((msg) {
      return !(msg['role'] == 'ai' &&
          msg['text']!.startsWith("Hi! I'm your AI Interview Coach"));
    }).toList();

    try {
      final reply = await _chatService.sendMessage(
        history,
        resumeId: currentResumeId,
        trainingType: currentTrainingType,
      );

      // أضف رد الـAI للنص
      setState(() {
        _messages.add({'role': 'ai', 'text': reply.text});
      });

      _scrollToBottom();

      // إذا فيه صوت من السيرفر، شغّله
      if (reply.audioBytes != null) {
        await _playAudio(reply.audioBytes!);
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'ai',
          'text': 'Oops! Something went wrong. 😅',
        });
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --------- BACK BUTTON HANDLER -----------
  Future<bool> _onWillPop() async {
    if (_messages.length <= 1) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content:
            const Text('Your chat history will be deleted if you leave.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ---------------- BUILD -------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _scaffoldBgColor,
        appBar: AppBar(
          title: const Text(
            'AI Interview Coach',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: _primaryColor,
          elevation: 2,
          centerTitle: true,
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),

            // Sparkie
            Center(
              child: Image.asset(
                _mouthOpen
                    ? 'assets/sparkie_open.png'
                    : 'assets/sparkie_closed.png',
                height: 170,
              ),
            ),

            const SizedBox(height: 8),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return _buildTypingIndicator();
                  }

                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? _primaryColor : _aiBubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(isUser ? 16 : 0),
                            bottomRight:
                                Radius.circular(isUser ? 0 : 16),
                          ),
                        ),
                        child: msg['role'] == 'ai'
                            ? MarkdownBody(
                                data: msg['text'] ?? '',
                                selectable: true,
                              )
                            : Text(
                                msg['text'] ?? '',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),

            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: _aiBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Text(
          "Typing...",
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[200]!, width: 1.0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: _isLoading
                      ? 'Coach is typing...'
                      : 'Type your interview question...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _isLoading ? null : (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor:
                  _isLoading ? Colors.grey : _primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
