import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import 'dart:async';

/// Colors used in the chat UI
const Color _primaryColor = Color(0xFF422F5D); // Main purple color
const Color _aiBubbleColor = Color(0xFFF1F1F1); // AI message bubble
const Color _scaffoldBgColor = Color(0xFFF8F9FA); // Background color

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final List<Map<String, String>> _messages = [];

  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // Variables for selected resume & training type
  String? _selectedResume;
  String? _selectedTrainingType;

  @override
  void initState() {
    super.initState();
    // Show setup sheet shortly after the screen loads
    Future.delayed(const Duration(milliseconds: 400), _showSetupSheet);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls to the bottom of the message list smoothly
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

  /// Sends user's message and gets AI reply
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Add user's message to list
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Send message to backend with selected resume & training type
      final reply = await _chatService.sendMessage(
        text,
        resumeId: _selectedResume,
        trainingType: _selectedTrainingType,
      );

      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Error: ${e.toString()}'});
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  /// Shows the setup sheet to pick resume and interview type
  void _showSetupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Set up your interview practice",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              /// --- Interview type dropdown ---
              const Text("Select training type:"),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTrainingType,
                items: const [
                  DropdownMenuItem(
                      value: "Technical Interview",
                      child: Text("Technical Interview")),
                  DropdownMenuItem(
                      value: "Behavioral Questions",
                      child: Text("Behavioral Questions")),
                  DropdownMenuItem(
                      value: "English Practice",
                      child: Text("English Practice")),
                  DropdownMenuItem(
                      value: "Job Interview", child: Text("Job Interview")),
                ],
                onChanged: (v) => setState(() => _selectedTrainingType = v),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),

              const SizedBox(height: 16),

              /// --- Resume dropdown ---
              const Text("Select Resume:"),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedResume,
                items: const [
                  DropdownMenuItem(
                      value: "resume1.pdf", child: Text("Resume 1")),
                  DropdownMenuItem(
                      value: "resume2.pdf", child: Text("Resume 2")),
                ],
                onChanged: (v) => setState(() => _selectedResume = v),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),

              const SizedBox(height: 24),

              /// --- Confirm button ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text("Setup complete! You can start chatting now.")),
                  );
                },
                child: const Text(
                  "Start",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSetupSheet,
            tooltip: "Change resume or training type",
          ),
        ],
      ),
      body: Column(
        children: [
          /// --- Chat messages list ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // Show typing indicator while AI is responding
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
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? _primaryColor : _aiBubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 16),
                        ),
                      ),
                      child: msg['role'] == 'ai'
                          ? MarkdownBody(
                              data: msg['text'] ?? '',
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    fontSize: 15, color: Colors.black87),
                              ),
                            )
                          : Text(
                              msg['text'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                color: isUser ? Colors.white : Colors.black87,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),

          /// --- Message input area ---
          _buildInputArea(),
        ],
      ),
    );
  }

  /// Typing indicator widget for AI
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _aiBubbleColor,
          borderRadius: const BorderRadius.only(
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

  /// Input area at the bottom of the screen
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
            /// --- Text Field ---
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type your interview question...',
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
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),

            /// --- Send button ---
            CircleAvatar(
              backgroundColor: _primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
