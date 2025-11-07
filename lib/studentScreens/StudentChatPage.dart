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
  // Controllers for text input and scrolling
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Services and state variables
  final ChatService _chatService = ChatService();
  // This list holds the chat messages in memory.
  // When the page is closed, this list is destroyed.
  final List<Map<String, String>> _messages = []; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add a friendly welcome message when the page loads
    _messages.add({
      'role': 'ai',
      'text':
          "Hi! I'm your AI Interview Coach. 👋\n\nAsk me any question to prepare for your interview."
    });
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls to the bottom of the message list
  void _scrollToBottom() {
    // Delay slightly to allow the UI to build before scrolling
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

  /// Handles sending the user's message to the ChatService
  void _sendMessage() async {
    final text = _controller.text.trim();
    // Don't send if the message is empty or if AI is already replying
    if (text.isEmpty || _isLoading) return;

    // --- (Example) Assume you get these IDs from your app's state ---
    // You must replace these with your real variables
    final String? currentResumeId = 'resume_12345'; // (Example: Get this from your state)
    final String? currentTrainingType = 'Software Development'; // (Example)

    final userMessage = {'role': 'user', 'text': text};
    
    // Add user's message to UI immediately
    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _isLoading = true; // Show typing indicator
    });

    _scrollToBottom(); // Scroll down

    // --- Filter out the welcome message from the history ---
    // The AI doesn't need to see its own welcome message
    final history = _messages.where((msg) {
        return !(msg['role'] == 'ai' && msg['text']!.startsWith("Hi! I'm your AI Interview Coach"));
    }).toList();


    try {
      // --- FIXED: The call now matches the ChatService ---
      // Call the AI service with history and extra parameters
      final reply = await _chatService.sendMessage(
        history, // Send the history List
        resumeId: currentResumeId,       // Send the extra parameters
        trainingType: currentTrainingType,
      );
      
      // Add AI's reply to the UI
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });
    } catch (e) {
      // Show an error message if the API call fails
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Oops! '});
      });
    } finally {
      // Whether it succeeded or failed, stop loading
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom(); // Scroll down to show the new message
    }
  }

  // --- NEW FUNCTION: Handles the back button press ---
  /// Shows a confirmation dialog before allowing the user to leave the page.
  Future<bool> _onWillPop() async {
    // If the user hasn't typed anything (only the welcome message exists),
    // let them leave without a warning.
    if (_messages.length <= 1) {
      return true; // (true = allow pop/exit)
    }

    // If they have chatted, show a confirmation dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Your chat history will be deleted if you leave.'),
        actions: <Widget>[
          // "Stay" button
          TextButton(
            onPressed: () => Navigator.pop(context, false), // (false = do not pop/exit)
            child: const Text('Cancel'),
          ),
          // "Leave" button
          TextButton(
            onPressed: () => Navigator.pop(context, true), // (true = allow pop/exit)
            child: const Text(
              'Leave',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    // Handle cases where the user taps outside the dialog (result is null)
    // (result ?? false) means: if result is null, treat it as false (don't exit)
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // --- MODIFIED: Wrap Scaffold with WillPopScope ---
    // This intercepts the back button press (both app bar and Android navigation)
    return WillPopScope(
      onWillPop: _onWillPop, // Call our new function to show the dialog
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
            // --- Message List Area ---
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                // Add 1 to item count if _isLoading is true (for the typing indicator)
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  
                  // If this is the last item AND we are loading, show the indicator
                  if (_isLoading && index == _messages.length) {
                    return _buildTypingIndicator();
                  }

                  // Get the message and check if it's from the user
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  // Align messages left (AI) or right (User)
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      // Limit message width to 75% of the screen
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? _primaryColor : _aiBubbleColor,
                          // Create the "chat bubble" shape
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 0),
                            bottomRight: Radius.circular(isUser ? 0 : 16),
                          ),
                        ),
                        // Use Markdown for AI replies (for formatting)
                        // Use standard Text for user replies
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
            
            // --- Text Input Area ---
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  /// Widget for the AI's "typing..." indicator
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
    // SafeArea ensures the input field isn't hidden by system UI (like the home bar)
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
            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isLoading, // Disable field while loading
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
                // Allow sending by pressing "enter" on keyboard
                onSubmitted: _isLoading ? null : (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            CircleAvatar(
              backgroundColor: _isLoading ? Colors.grey : _primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                // Disable button while loading
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}