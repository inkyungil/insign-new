// lib/features/chatbot/view/chatbot_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:insign/models/chat_message.dart';

class ChatbotScreen extends StatefulWidget {
  final Map<String, dynamic>? stockInfo;
  final String? autoQuestion;
  
  const ChatbotScreen({
    super.key, 
    this.stockInfo,
    this.autoQuestion,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  final List<QuickAction> _quickActions = const [
    QuickAction(id: '1', title: '주식 종목', query: '삼성전자 주식 분석해줘'),
    QuickAction(id: '2', title: '삼성전자', query: '삼성전자 투자 전망은?'),
  ];

  @override
  void initState() {
    super.initState();
    _addInitialMessage();
    // 종목 정보와 함께 진입한 경우 자동 질문 처리
    if (widget.autoQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSubmitted(widget.autoQuestion!);
      });
    }
  }

  void _addInitialMessage() {
    final initialMessage = ChatMessage(
      id: '0',
      content: '안녕하세요! AI 투자 어시스턴트입니다. 투자와 관련된 궁금한 점을 언제든 물어보세요. 📊',
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(initialMessage);
    });
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();
    
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _scrollToBottom();

    // Simulate AI response
    Future.delayed(const Duration(seconds: 2), () {
      final response = _generateResponse(text);
      final assistantMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response,
        sender: MessageSender.assistant,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(assistantMessage);
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  String _generateResponse(String userInput) {
    final input = userInput.toLowerCase();
    
    // 투자 페이지에서 전달받은 종목 정보가 있는 경우
    if (widget.stockInfo != null) {
      final stock = widget.stockInfo!;
      final stockName = stock['name'] ?? '';
      final stockCode = stock['code'] ?? '';
      final price = stock['price'] ?? '';
      final change = stock['change'] ?? '';
      final changeType = stock['changeType'] ?? 'up';
      final category = stock['category'] ?? '';
      
      if (input.contains('매수') || input.contains('매도') || input.contains(stockName.toLowerCase())) {
        return _generateStockAnalysis(stockName, stockCode, price, change, changeType, category);
      }
    }
    
    // 기존 로직들
    if (input.contains('삼성전자') || input.contains('005930')) {
      return '삼성전자(005930)는 현재 상승 추세를 보이고 있습니다. 최근 메모리 반도체 시장 회복과 AI 관련 수요 증가로 긍정적인 전망을 보이고 있어요. 다만 글로벌 경제 불확실성을 고려한 리스크 관리가 필요합니다.';
    } else if (input.contains('투자') || input.contains('포트폴리오')) {
      return '투자 포트폴리오 구성 시 분산투자가 중요합니다. 주식, 채권, 현금 비중을 적절히 조절하고, 개별 종목보다는 섹터별 분산을 권장드려요. 현재 시장 상황을 고려하여 맞춤형 조언을 드릴 수 있습니다.';
    } else if (input.contains('시장') || input.contains('증시')) {
      return '현재 증시는 변동성이 큰 상황입니다. 글로벌 금리 정책과 지정학적 리스크가 주요 변수로 작용하고 있어요. 단기적으로는 신중한 접근이, 장기적으로는 우량 기업 중심의 투자를 권장합니다.';
    } else {
      return '좋은 질문이네요! 투자 관련해서 더 구체적인 질문을 해주시면 더 정확한 분석과 조언을 드릴 수 있습니다. 특정 종목이나 투자 전략에 대해 궁금한 점이 있으시면 언제든 물어보세요.';
    }
  }

  String _generateStockAnalysis(String name, String code, String price, String change, String changeType, String category) {
    final isUp = changeType == 'up';
    final categoryText = category == '코인' ? '암호화폐' : '주식';
    final signal = isUp ? '매수 관심' : '매도 검토';
    
    return '''📊 $name($code) AI 분석 결과

🔹 현재가: $price원
🔹 전일대비: ${isUp ? '📈' : '📉'} $change
🔹 시장구분: $categoryText

💡 **AI 판단: $signal**

**기술적 분석:**
- ${isUp ? 'RSI 지표 상승 추세, 이동평균선 정배열 형성' : 'RSI 지표 과매수 구간, 단기 조정 가능성'}
- ${isUp ? '거래량 증가로 상승 모멘텀 확인' : '거래량 감소로 상승세 둔화'}

**뉴스 분석:**
- ${isUp ? '긍정적 공시 및 호재성 뉴스 확인' : '일부 우려 요소 포착, 신중한 접근 필요'}

**투자 조언:**
${isUp ? '💎 현재 상승 추세이나 분할 매수를 통한 리스크 관리 권장' : '⚠️ 단기 조정 가능성이 높아 관망 또는 부분 매도 검토'}

*본 정보는 참고용이며, 투자 결정은 본인 책임입니다.*''';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _formatTime(DateTime dateTime) {
    return '오후 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_messages.length == 1) _buildQuickActions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.sender == MessageSender.user;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.smart_toy,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                      bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser 
                          ? theme.colorScheme.onPrimary 
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Icon(
              Icons.smart_toy,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + (index * 200)),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '빠른 질문',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: _quickActions.map((action) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(action.title),
                  onPressed: () => _handleSubmitted(action.query),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: '투자 관련 질문을 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onSubmitted: _handleSubmitted,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: Icon(
                Icons.send,
                color: theme.colorScheme.onPrimary,
                size: 20,
              ),
              onPressed: () => _handleSubmitted(_textController.text),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}