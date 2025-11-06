import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart'; // Make sure this path is correct
import 'dart:async'; // For using Future.delayed

// --- 1. Define key colors ---
const Color _primaryColor = Color(0xFF422F5D);
const Color _aiBubbleColor = Color(0xFFF1F1F1);
const Color _scaffoldBgColor = Color(0xFFF8F9FA);

// Renamed to StudentChatPage
class StudentChatPage extends StatefulWidget {
  const StudentChatPage({super.key});

  @override
  State<StudentChatPage> createState() => _StudentChatPageState();
}

// Renamed to _StudentChatPageState
class _StudentChatPageState extends State<StudentChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add a friendly welcome message
    _messages.add({
      'role': 'ai',
      'text':
          "Hi! I'm your AI Interview Coach. 👋\n\nAsk me any question to prepare for your interview."
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Function to scroll to the bottom
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

  // --- UPDATED Send Message Function ---
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    // --- (Example) Assume you get these IDs from your app's state ---
    // You must replace these with your real variables
    final String? currentResumeId = 'resume_12345'; // (Example: Get this from your state)
    final String? currentTrainingType = 'Software Development'; // (Example)

    final userMessage = {'role': 'user', 'text': text};
    
    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    // --- Filter out the welcome message from the history ---
    final history = _messages.where((msg) {
        return !(msg['role'] == 'ai' && msg['text']!.startsWith("Hi! I'm your AI Interview Coach"));
    }).toList();


    try {
      // --- FIXED: The call now matches the ChatService ---
      final reply = await _chatService.sendMessage(
        history, // Send the history List
        resumeId: currentResumeId,       // Send the extra parameters
        trainingType: currentTrainingType,
      );
      
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });
    } catch (e) {
      setState(() {
        // Show the error from the ChatService
        _messages.add({'role': 'ai', 'text': 'Oops! ${e.toString()} 😟'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
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
      ),
      body: Column(
        children: [
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
                              selectable: true, // Allows student to copy text
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    fontSize: 15, color: Colors.black87),
                                strong: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                listBullet: const TextStyle(
                                    fontSize: 15, color: Colors.black87),
                              ),
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
    );
  }

  /// Widget for the AI's "typing" indicator
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

  /// Widget for the text input area at the bottom
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
              backgroundColor: _isLoading ? Colors.grey : _primaryColor,
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