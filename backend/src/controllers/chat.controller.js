const Groq = require('groq-sdk');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY
});

// Lưu trữ conversation history (trong production nên dùng Redis/Database)
const conversationHistory = new Map();

const SYSTEM_PROMPT = `Bạn là trợ lý AI quản lý tài chính cá nhân thông minh tên là "FinBot".

Nhiệm vụ của bạn:
1. Giúp người dùng theo dõi và quản lý thu chi hàng ngày
2. Đưa ra lời khuyên tiết kiệm dựa trên thói quen chi tiêu
3. Trả lời các câu hỏi về tài chính cá nhân
4. Giúp lập kế hoạch ngân sách

Quy tắc:
- Trả lời bằng tiếng Việt
- Ngắn gọn, rõ ràng, thân thiện
- Sử dụng emoji phù hợp để tạo cảm giác gần gũi
- Khi người dùng hỏi về chi tiêu cụ thể, hãy hỏi thêm chi tiết nếu cần
- Đưa ra lời khuyên thiết thực và dễ thực hiện

Ví dụ tương tác:
- User: "Tháng này tôi nên chi bao nhiêu cho ăn uống?"
- Bot: "Theo nguyên tắc 50/30/20, bạn nên dành khoảng 30-35% thu nhập cho chi phí thiết yếu bao gồm ăn uống. Nếu thu nhập của bạn là 10 triệu, khoảng 3-3.5 triệu/tháng cho ăn uống là hợp lý. 🍜"`;

/**
 * Gửi tin nhắn và nhận phản hồi từ AI
 */
exports.sendMessage = async (req, res) => {
  try {
    const { message, conversationId } = req.body;
    const userId = req.user?.id || 'anonymous';

    if (!message || message.trim() === '') {
      return res.status(400).json({ 
        success: false,
        error: 'Message is required' 
      });
    }

    // Lấy hoặc tạo conversation history
    const historyKey = conversationId || `${userId}-${Date.now()}`;
    let history = conversationHistory.get(historyKey) || [];

    // Thêm tin nhắn user vào history
    history.push({
      role: 'user',
      content: message
    });

    // Giới hạn history để không vượt quá context window
    if (history.length > 20) {
      history = history.slice(-20);
    }

    // Gọi Groq API
    const completion = await groq.chat.completions.create({
      model: 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        ...history
      ],
      temperature: 0.7,
      max_tokens: 1024,
      top_p: 1,
      stream: false
    });

    const aiResponse = completion.choices[0]?.message?.content || 'Xin lỗi, tôi không thể trả lời lúc này.';

    // Thêm response vào history
    history.push({
      role: 'assistant',
      content: aiResponse
    });

    // Lưu history
    conversationHistory.set(historyKey, history);

    // Xóa history cũ sau 1 giờ
    setTimeout(() => {
      conversationHistory.delete(historyKey);
    }, 60 * 60 * 1000);

    res.json({
      success: true,
      data: {
        message: aiResponse,
        conversationId: historyKey
      }
    });

  } catch (error) {
    console.error('Chat error:', error);
    
    // Xử lý lỗi cụ thể từ Groq
    if (error.status === 401) {
      return res.status(401).json({
        success: false,
        error: 'Invalid API key. Please check your GROQ_API_KEY.'
      });
    }
    
    if (error.status === 429) {
      return res.status(429).json({
        success: false,
        error: 'Rate limit exceeded. Please try again later.'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to process message'
    });
  }
};

/**
 * Xóa conversation history
 */
exports.clearHistory = async (req, res) => {
  try {
    const { conversationId } = req.body;
    
    if (conversationId) {
      conversationHistory.delete(conversationId);
    }

    res.json({
      success: true,
      message: 'Conversation history cleared'
    });
  } catch (error) {
    console.error('Clear history error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to clear history'
    });
  }
};
