const Groq = require('groq-sdk');
const supabase = require('../config/supabase');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY
});

// Lưu trữ conversation history
const conversationHistory = new Map();

const SYSTEM_PROMPT = `Bạn là trợ lý AI quản lý tài chính cá nhân thông minh tên là "FinBot".

QUAN TRỌNG - KHẢ NĂNG CỦA BẠN:
1. Tư vấn quản lý chi tiêu, tiết kiệm
2. Trả lời câu hỏi về tài chính
3. **TẠO GIAO DỊCH**: Khi người dùng muốn ghi chi tiêu/thu nhập

KHI NGƯỜI DÙNG MUỐN GHI CHI TIÊU/THU NHẬP:
- Nếu họ nói "ghi chi tiêu", "thêm chi tiêu", "mua xxx", "tiêu xxx", "chi xxx"
- Bạn PHẢI trả lời theo format JSON đặc biệt để hệ thống tự động tạo giao dịch

FORMAT TẠO GIAO DỊCH (BẮT BUỘC theo đúng format):
[CREATE_TRANSACTION]
{
  "action": "create_transaction",
  "type": "expense",
  "amount": 50000,
  "category": "Ăn uống",
  "description": "Mô tả ngắn"
}
[/CREATE_TRANSACTION]

Sau đó thêm tin nhắn xác nhận cho người dùng.

DANH MỤC HỢP LỆ:
- Chi tiêu (expense): "Ăn uống", "Di chuyển", "Mua sắm", "Giải trí", "Sức khỏe", "Giáo dục", "Hóa đơn", "Khác"
- Thu nhập (income): "Lương", "Thưởng", "Đầu tư", "Khác"

VÍ DỤ:
User: "ghi chi tiêu 50k ăn sáng"
Bot: 
[CREATE_TRANSACTION]
{"action": "create_transaction", "type": "expense", "amount": 50000, "category": "Ăn uống", "description": "Ăn sáng"}
[/CREATE_TRANSACTION]

✅ Đã ghi chi tiêu 50,000đ cho Ăn sáng vào danh mục Ăn uống!

User: "mua cafe 35k"
Bot:
[CREATE_TRANSACTION]
{"action": "create_transaction", "type": "expense", "amount": 35000, "category": "Ăn uống", "description": "Mua cafe"}
[/CREATE_TRANSACTION]

✅ Đã ghi chi tiêu 35,000đ cho Mua cafe!

User: "nhận lương 10 triệu"
Bot:
[CREATE_TRANSACTION]
{"action": "create_transaction", "type": "income", "amount": 10000000, "category": "Lương", "description": "Nhận lương tháng"}
[/CREATE_TRANSACTION]

✅ Đã ghi thu nhập 10,000,000đ - Lương!

QUY TẮC:
- Trả lời bằng tiếng Việt, thân thiện, dùng emoji
- Chuyển đổi: "50k" = 50000, "1tr" = 1000000, "1 triệu" = 1000000
- Nếu thiếu thông tin, hỏi lại người dùng
- Luôn xác nhận sau khi tạo giao dịch`;

/**
 * Gửi tin nhắn và nhận phản hồi từ AI
 */
exports.sendMessage = async (req, res) => {
  try {
    const { message, conversationId } = req.body;
    const userId = req.user?.id;

    if (!message || message.trim() === '') {
      return res.status(400).json({ 
        success: false,
        error: 'Message is required' 
      });
    }

    // Lấy hoặc tạo conversation history
    const historyKey = conversationId || `${userId || 'anon'}-${Date.now()}`;
    let history = conversationHistory.get(historyKey) || [];

    // Thêm tin nhắn user vào history
    history.push({
      role: 'user',
      content: message
    });

    // Giới hạn history
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
    });

    let aiResponse = completion.choices[0]?.message?.content || 'Xin lỗi, tôi không thể trả lời lúc này.';

    // Kiểm tra và xử lý lệnh tạo giao dịch
    let transactionCreated = null;
    const transactionMatch = aiResponse.match(/\[CREATE_TRANSACTION\]([\s\S]*?)\[\/CREATE_TRANSACTION\]/);
    
    if (transactionMatch && userId) {
      try {
        const transactionData = JSON.parse(transactionMatch[1].trim());
        
        if (transactionData.action === 'create_transaction') {
          // Tìm category ID
          const { data: categories } = await supabase
            .from('categories')
            .select('id, name')
            .eq('user_id', userId);
          
          let categoryId = null;
          const categoryName = transactionData.category || 'Khác';
          
          // Tìm category phù hợp
          const matchedCategory = categories?.find(c => 
            c.name.toLowerCase().includes(categoryName.toLowerCase()) ||
            categoryName.toLowerCase().includes(c.name.toLowerCase())
          );
          
          if (matchedCategory) {
            categoryId = matchedCategory.id;
          } else {
            // Tạo category mới nếu chưa có
            const { data: newCat } = await supabase
              .from('categories')
              .insert({
                user_id: userId,
                name: categoryName,
                type: transactionData.type || 'expense',
                icon: '📝',
                color: '#808080'
              })
              .select()
              .single();
            categoryId = newCat?.id;
          }

          if (categoryId) {
            // Tạo giao dịch
            const { data: transaction, error } = await supabase
              .from('transactions')
              .insert({
                user_id: userId,
                category_id: categoryId,
                amount: transactionData.amount,
                type: transactionData.type || 'expense',
                description: transactionData.description || '',
                transaction_date: new Date().toISOString().split('T')[0]
              })
              .select()
              .single();

            if (!error && transaction) {
              transactionCreated = {
                id: transaction.id,
                amount: transactionData.amount,
                type: transactionData.type,
                category: categoryName,
                description: transactionData.description
              };
              console.log('✅ Transaction created:', transactionCreated);
            } else {
              console.error('❌ Failed to create transaction:', error);
            }
          }
        }
      } catch (parseError) {
        console.error('❌ Failed to parse transaction:', parseError);
      }

      // Xóa phần JSON khỏi response để user không thấy
      aiResponse = aiResponse.replace(/\[CREATE_TRANSACTION\][\s\S]*?\[\/CREATE_TRANSACTION\]/, '').trim();
    }

    // Nếu không có userId nhưng AI muốn tạo giao dịch
    if (transactionMatch && !userId) {
      aiResponse = aiResponse.replace(/\[CREATE_TRANSACTION\][\s\S]*?\[\/CREATE_TRANSACTION\]/, '').trim();
      aiResponse += '\n\n⚠️ Bạn cần đăng nhập để tôi có thể ghi chi tiêu cho bạn.';
    }

    // Thêm response vào history
    history.push({
      role: 'assistant',
      content: aiResponse
    });

    conversationHistory.set(historyKey, history);

    // Xóa history sau 1 giờ
    setTimeout(() => {
      conversationHistory.delete(historyKey);
    }, 60 * 60 * 1000);

    res.json({
      success: true,
      data: {
        message: aiResponse,
        conversationId: historyKey,
        transactionCreated
      }
    });

  } catch (error) {
    console.error('Chat error:', error);
    
    if (error.status === 401) {
      return res.status(401).json({
        success: false,
        error: 'Invalid API key'
      });
    }
    
    if (error.status === 429) {
      return res.status(429).json({
        success: false,
        error: 'Rate limit exceeded'
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
    res.status(500).json({
      success: false,
      error: 'Failed to clear history'
    });
  }
};
