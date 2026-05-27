import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/chat_service.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _typingAnimationController;

  // Quick suggestions
  final List<Map<String, String>> _quickSuggestions = [
    {
      'label': '💰 Tiết kiệm',
      'prompt': 'Gợi ý cho mình 3 cách tiết kiệm tiền phù hợp với chi tiêu hiện tại.',
    },
    {
      'label': '📊 Phân tích chi tiêu',
      'prompt': 'Phân tích chi tiêu tháng này của mình và chỉ ra khoản nào cần chú ý.',
    },
    {
      'label': '🎯 Lập ngân sách',
      'prompt': 'Lập ngân sách cho số tiền còn lại đến cuối tháng giúp mình.',
    },
    {
      'label': '⚡ Ghi nhanh',
      'prompt': 'Hướng dẫn mình ghi thu chi nhanh bằng tin nhắn ngắn.',
    },
  ];
  List<Map<String, String>> _followUpSuggestions = [];

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Welcome message
    _messages.add(ChatMessage(
      content: 'Xin chào! 👋 Mình là FinBot - trợ lý tài chính AI của bạn.\n\n'
          'Mình có thể giúp bạn ghi nhanh thu chi, xem số dư, phân tích chi tiêu và lập ngân sách. Bạn cứ nhắn tự nhiên, ví dụ: "50k cafe" hoặc "lương 15tr".',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickMessage]) async {
    final text = quickMessage ?? _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (quickMessage == null) {
      _controller.clear();
    }
    _focusNode.unfocus();

    setState(() {
      _messages.add(ChatMessage(content: text, isUser: true));
      _followUpSuggestions = [];
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final authToken = session?.accessToken;

      final response = await ChatService.sendMessage(text, authToken: authToken);

      final isError = response.message.contains('❌') || 
                      response.message.contains('🔌') || 
                      response.message.contains('⏱️') ||
                      response.message.contains('🔑');

      setState(() {
        _messages.add(ChatMessage(
          content: response.message,
          isUser: false,
          isError: isError,
        ));
        _followUpSuggestions = isError ? [] : _buildSmartSuggestions(text, response);
        _isLoading = false;
      });

      // Hiển thị thông báo nếu tạo giao dịch thành công
      if (response.hasTransaction && mounted) {
        final tx = response.transactionCreated!;
        final type = tx['type'] == 'income' ? 'Thu nhập' : 'Chi tiêu';
        final amount = tx['amount'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã ghi $type: ${_formatCurrency(amount)}'),
            backgroundColor: tx['type'] == 'income' ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          content: '❌ Xin lỗi, có lỗi xảy ra. Vui lòng thử lại sau.',
          isUser: false,
          isError: true,
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  String _formatCurrency(num value) {
    return '${(value / 1000).toStringAsFixed(0)}k đ';
  }

  List<Map<String, String>> _buildSmartSuggestions(String userText, ChatResponse response) {
    final text = userText.toLowerCase();
    final reply = response.message.toLowerCase();

    if (response.hasTransaction) {
      return [
        {
          'label': '💳 Xem số dư',
          'prompt': 'Số dư hiện tại của mình là bao nhiêu?',
        },
        {
          'label': '🎯 Chia ngân sách',
          'prompt': 'Với số dư còn lại, mình nên chi tiêu thế nào đến cuối tháng?',
        },
        {
          'label': '📊 Phân tích tháng này',
          'prompt': 'Phân tích nhanh thu nhập và chi tiêu tháng này của mình.',
        },
      ];
    }

    if (text.contains('ngân sách') || text.contains('số dư') || reply.contains('số dư')) {
      return [
        {
          'label': '🍽️ Chia theo ngày',
          'prompt': 'Chia số tiền còn lại thành hạn mức chi tiêu mỗi ngày giúp mình.',
        },
        {
          'label': '🧾 Ưu tiên khoản cần',
          'prompt': 'Những khoản nào mình nên ưu tiên trả trước trong tháng này?',
        },
        {
          'label': '🚫 Khoản nên cắt',
          'prompt': 'Gợi ý các khoản mình nên hạn chế để không vượt ngân sách.',
        },
      ];
    }

    if (text.contains('tiết kiệm') || text.contains('mẹo')) {
      return [
        {
          'label': '📌 Kế hoạch 7 ngày',
          'prompt': 'Lập cho mình kế hoạch tiết kiệm trong 7 ngày tới.',
        },
        {
          'label': '🔍 Tìm khoản lãng phí',
          'prompt': 'Dựa vào chi tiêu tháng này, khoản nào có thể đang bị lãng phí?',
        },
        {
          'label': '🎯 Mục tiêu nhỏ',
          'prompt': 'Gợi ý một mục tiêu tiết kiệm nhỏ và dễ làm cho mình.',
        },
      ];
    }

    return [
      {
        'label': '💳 Xem số dư',
        'prompt': 'Số dư hiện tại của mình là bao nhiêu?',
      },
      {
        'label': '📊 Phân tích chi tiêu',
        'prompt': 'Phân tích chi tiêu tháng này của mình.',
      },
      {
        'label': '✍️ Ghi giao dịch',
        'prompt': 'Mình muốn ghi một giao dịch mới.',
      },
    ];
  }

  void _retryLastMessage() {
    if (_messages.length >= 2) {
      // Tìm tin nhắn user cuối cùng
      for (int i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i].isUser) {
          final lastUserMessage = _messages[i].content;
          // Xóa tin nhắn lỗi
          setState(() {
            _messages.removeWhere((m) => m.isError);
          });
          _sendMessage(lastUserMessage);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.blue.shade500],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FinBot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isLoading ? Colors.orange : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isLoading ? 'Đang trả lời...' : 'Online',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearDialog(),
            tooltip: 'Xóa cuộc trò chuyện',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Quick suggestions
          if (!_isLoading && _messages.length <= 2)
            _buildSuggestionChips(_quickSuggestions),
          if (!_isLoading && _messages.length > 2 && _followUpSuggestions.isNotEmpty)
            _buildSuggestionChips(_followUpSuggestions),

          // Input area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Nhập câu hỏi của bạn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        prefixIcon: Icon(Icons.chat_bubble_outline, 
                            color: colorScheme.onSurfaceVariant, size: 20),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading,
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isLoading 
                            ? [Colors.grey.shade400, Colors.grey.shade500]
                            : [Colors.teal.shade400, Colors.blue.shade500],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: _isLoading ? [] : [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isLoading ? Icons.hourglass_empty : Icons.send_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _isLoading ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cuộc trò chuyện?'),
        content: const Text('Tất cả tin nhắn sẽ bị xóa và không thể khôi phục.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ChatService.clearHistory();
              setState(() {
                _messages.clear();
                _followUpSuggestions = [];
                _messages.add(ChatMessage(
                  content: '🎉 Đã bắt đầu cuộc trò chuyện mới!\n\nMình có thể giúp gì cho bạn?',
                  isUser: false,
                ));
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(List<Map<String, String>> suggestions) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((suggestion) {
          return ActionChip(
            avatar: const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              suggestion['label']!,
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _sendMessage(suggestion['prompt']!),
            backgroundColor: colorScheme.surfaceContainerHighest,
            side: BorderSide(color: colorScheme.outlineVariant),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: message.isError 
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : [Colors.teal.shade400, Colors.blue.shade500],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                message.isError ? Icons.error_outline : Icons.smart_toy,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyMessage(message.content),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Colors.teal.shade500
                      : message.isError
                          ? Colors.red.shade50
                          : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                    bottomRight: Radius.circular(message.isUser ? 4 : 20),
                  ),
                  border: message.isError
                      ? Border.all(color: Colors.red.shade200)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: message.isUser
                            ? Colors.white
                            : message.isError
                                ? Colors.red.shade700
                                : colorScheme.onSurface,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    if (message.isError) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _retryLastMessage,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 14, color: Colors.red.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Thử lại',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.teal.shade100,
              child: Icon(Icons.person, size: 18, color: Colors.teal.shade700),
            ),
          ],
        ],
      ),
    );
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép tin nhắn'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.blue.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimationController,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.2;
                    final value = (_typingAnimationController.value + delay) % 1.0;
                    final opacity = (value < 0.5) ? value * 2 : (1 - value) * 2;
                    return Container(
                      margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.3 + opacity * 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Đang suy nghĩ...',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
