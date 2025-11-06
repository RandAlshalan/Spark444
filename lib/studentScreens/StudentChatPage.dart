import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/student.dart'; // Make sure this path is correct
import '../models/message.dart'; // Make sure this path is correct
import '../services/chat_service.dart'; // Make sure this path is correct
import 'dart:async'; // For Future.delayed

// --- 1. Define key colors (from StudentChatPage) ---
const Color _primaryColor = Color(0xFF422F5D);
const Color _aiBubbleColor = Color(0xFFF1F1F1);
const Color _userBubbleColor = _primaryColor; // Use primary for user
const Color _scaffoldBgColor = Color(0xFFF8F9FA);

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService(); // Use one service instance

  bool _isLoading = false;
  String? _currentChatId; // Current chat session ID

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls to bottom of chat
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

  /// Create a new chat session
  Future<void> _createNewChat(String userId) async {
    // Add a default "title" or generate one
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('chats')
        .add({
      'title': 'New Chat @ ${DateTime.now().toShortDateString()}',
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() => _currentChatId = docRef.id);

    // Optional: Add the default welcome message to this new chat
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .add({
      'role': 'ai',
      'text': "Hi! I'm your AI Interview Coach. 👋\n\nAsk me any question to prepare for your interview.",
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get the current chat history from Firestore
  Future<List<Map<String, String>>> _getChatHistory(String userId) async {
    if (_currentChatId == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    // Filter out the welcome message for the history
    return snapshot.docs.map((doc) {
      return {
        'role': doc['role'] as String,
        'text': doc['text'] as String,
      };
    }).where((msg) => 
        !(msg['role'] == 'ai' && msg['text']!.startsWith("Hi! I'm your AI Interview Coach"))
    ).toList();
  }

  /// Send user message and get AI reply
  Future<void> _sendMessage(Student student) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _currentChatId == null) return;

    final userId = student.id;
    _controller.clear();
    setState(() => _isLoading = true);
    _scrollToBottom(); // Scroll after user sends

    final messagesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages');

    // 1. Save user's message
    await messagesRef.add({
      'role': 'user',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    try {
      // 2. Get current history for the API call
      final history = await _getChatHistory(userId);

      // 3. Call AI service (using the advanced method from StudentChatPage)
      final replyText = await _chatService.sendMessage(
        history, // Send the history List
      );

      // 4. Save AI reply
      await messagesRef.add({
        'role': 'ai',
        'text': replyText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // 5. Save error message
      await messagesRef.add({
        'role': 'ai',
        'text': 'Oops! ${e.toString()} 😟',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom(); // Scroll after AI replies
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the Student object from Provider
    final student = context.watch<Student?>();

    if (student == null) {
      return const Scaffold(
        body: Center(child: Text("Loading student profile... Please log in.")),
      );
    }
    
    final userId = student.id;

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
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: "Start new chat",
            onPressed: () => _createNewChat(userId),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Chat session selector ---
          SizedBox(
            height: 60, // Reduced height a bit
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('chats')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final chats = snapshot.data!.docs;
                if (chats.isEmpty && _currentChatId == null) {
                  // If no chats exist, create one automatically
                  Future.microtask(() => _createNewChat(userId));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final chatId = chat.id;
                    final title = (chat.data() as Map<String, dynamic>)['title'] ?? 'Untitled';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                      child: ChoiceChip(
                        label: Text(title),
                        selectedColor: _primaryColor,
                        labelStyle: TextStyle(
                          color: _currentChatId == chatId ? Colors.white : _primaryColor,
                        ),
                        selected: _currentChatId == chatId,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _currentChatId = chatId);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // --- Messages List ---
          Expanded(
            child: _currentChatId == null
                ? const Center(child: Text("Start a chat or select one"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('chats')
                        .doc(_currentChatId)
                        .collection('messages')
                        .orderBy('timestamp')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // We have data, so scroll to bottom
                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                      final msgs = snapshot.data!.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: msgs.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          
                          if (_isLoading && index == msgs.length) {
                            return _buildTypingIndicator();
                          }

                          final msg = msgs[index];
                          final isUser = msg.role == 'user';

                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser ? _userBubbleColor : _aiBubbleColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isUser ? 16 : 0),
                                    bottomRight: Radius.circular(isUser ? 0 : 16),
                                  ),
                                ),
                                child: msg.role == 'ai'
                                    ? MarkdownBody(
                                        data: msg.text,
                                        selectable: true,
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
                                        msg.text,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          
          // --- Input area ---
          _buildInputArea(onSend: () => _sendMessage(student)),
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
  Widget _buildInputArea({required VoidCallback onSend}) {
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
                onSubmitted: _isLoading ? null : (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _isLoading ? Colors.grey : _primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _isLoading ? null : onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper extension for dates
extension DateHelpers on DateTime {
  String toShortDateString() {
    return "${this.month}/${this.day}/${this.year}";
  }
}