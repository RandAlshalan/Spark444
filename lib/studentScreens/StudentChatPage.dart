import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/chat_service.dart';
import 'dart:async'; // لاستخدام Future.delayed

// --- 1. تعريف الألوان الرئيسية ---
// استخدام الألوان الثابتة يمنح التطبيق هوية موحدة
const Color _primaryColor = Color(0xFF422F5D); // لون أساسي داكن (كما في ملفاتك السابقة)
const Color _aiBubbleColor = Color(0xFFF1F1F1); // لون فاتح لرسائل الـ AI
const Color _scaffoldBgColor = Color(0xFFF8F9FA); // لون خلفية خفيف جداً

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

  // --- 2. إضافة ScrollController ---
  // هذا ضروري لتحريك القائمة للأسفل تلقائياً
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose(); // لا تنسى التخلص منه
    super.dispose();
  }

  // --- 3. دالة لتحريك القائمة للأسفل ---
  void _scrollToBottom() {
    // ننتظر لحظة قصيرة ليتم بناء الواجهة، ثم نحرك
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _controller.clear();
      _isLoading = true; // --- 4. إظهار مؤشر "الكتابة" ---
    });

    _scrollToBottom(); // تحريك بعد إرسال رسالة المستخدم

    try {
      final reply = await _chatService.sendMessage(text);
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Error: ${e.toString()}'});
      });
    } finally {
      setState(() {
        _isLoading = false; // إخفاء مؤشر "الكتابة"
      });
      _scrollToBottom(); // تحريك بعد استلام رسالة الـ AI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBgColor, // --- 5. لون خلفية مخصص ---
      appBar: AppBar(
        title: const Text(
          'AI Interview Coach',
          style: TextStyle(
            color: Colors.white, // لون أبيض ليتناسب مع الخلفية الداكنة
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _primaryColor, // --- 6. استخدام اللون الأساسي ---
        elevation: 2,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // --- 7. ربط الـ Controller ---
              padding: const EdgeInsets.all(12),
              // --- 8. إضافة مكان لمؤشر "الكتابة" ---
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                
                // --- 9. إظهار مؤشر "الكتابة" ---
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }

                final msg = _messages[index];
                final isUser = msg['role'] == 'user';

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  // --- 10. تحديد عرض أقصى للرسائل ---
                  // هذا يمنع الرسائل من ملء الشاشة عرضياً
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        // --- 11. ألوان جديدة للرسائل ---
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
                                p: const TextStyle(fontSize: 15, color: Colors.black87),
                                // ... (يمكنك تخصيص باقي الـ styles هنا)
                                // ...
                              ),
                            )
                          : Text(
                              msg['text'] ?? '',
                              // --- 12. نص أبيض لرسالة المستخدم ---
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
          
          // --- 13. فصل منطقة الإدخال في ودجت خاص ---
          _buildInputArea(),
        ],
      ),
    );
  }

  /// ودجت لمؤشر "الكتابة" الخاص بالـ AI
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

  /// ودجت لمنطقة إدخال النص في الأسفل
  Widget _buildInputArea() {
    // --- 14. استخدام SafeArea و Container ---
    // هذا يضمن عدم تداخل الواجهة مع شريط سفلي (مثل iPhone)
    // ويمنحنا خلفية بيضاء ثابتة
    
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
            CircleAvatar(
              backgroundColor: _primaryColor, // --- 15. استخدام اللون الأساسي ---
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
