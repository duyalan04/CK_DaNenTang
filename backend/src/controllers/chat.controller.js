const Groq = require('groq-sdk');
const supabase = require('../config/supabase');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY
});

// Lưu trữ conversation history
const conversationHistory = new Map();

const FINANCE_KNOWLEDGE = `
KIẾN THỨC TÀI CHÍNH CÁ NHÂN VIỆT NAM:

1. QUY TẮC QUẢN LÝ TIỀN:
- Quy tắc 50/30/20: 50% nhu cầu thiết yếu, 30% mong muốn, 20% tiết kiệm/đầu tư
- Quy tắc 6 chiếc lọ: Thiết yếu 55%, Tiết kiệm dài hạn 10%, Giáo dục 10%, Hưởng thụ 10%, Đầu tư 10%, Từ thiện 5%
- Quỹ khẩn cấp: Nên có 3-6 tháng chi tiêu

2. LÃI SUẤT & LẠM PHÁT VN (2024-2025):
- Lãi suất tiết kiệm: 4-6%/năm (kỳ hạn 12 tháng)
- Lạm phát: 3-4%/năm
- Lãi suất vay mua nhà: 8-12%/năm
- Lãi suất thẻ tín dụng: 20-30%/năm (rất cao, tránh nợ)

3. CHI TIÊU TRUNG BÌNH (tham khảo):
- Sinh viên: 3-5 triệu/tháng
- Người đi làm độc thân: 8-15 triệu/tháng
- Gia đình nhỏ: 15-25 triệu/tháng
- Tiền thuê nhà: 20-30% thu nhập
- Ăn uống: 25-35% thu nhập

4. TIẾT KIỆM & ĐẦU TƯ:
- Gửi tiết kiệm ngân hàng: An toàn, lãi thấp
- Chứng chỉ quỹ: Rủi ro trung bình, lãi 8-15%/năm
- Cổ phiếu: Rủi ro cao, cần kiến thức
- Vàng: Bảo toàn giá trị, chống lạm phát
- Bất động sản: Vốn lớn, dài hạn

5. BẢO HIỂM:
- BHXH bắt buộc: 10.5% lương
- BHYT: 1.5% lương
- Bảo hiểm nhân thọ: 5-10% thu nhập (tùy chọn)

6. THUẾ THU NHẬP CÁ NHÂN:
- Mức giảm trừ bản thân: 11 triệu/tháng
- Giảm trừ người phụ thuộc: 4.4 triệu/người/tháng
- Thu nhập chịu thuế = Tổng thu nhập - Giảm trừ - BHXH

7. MẸO TIẾT KIỆM:
- Ghi chép chi tiêu hàng ngày
- Đặt mục tiêu tiết kiệm cụ thể
- Tự động chuyển tiền tiết kiệm đầu tháng
- So sánh giá trước khi mua
- Hạn chế mua sắm online bốc đồng
- Nấu ăn tại nhà thay vì ăn ngoài
`;

const SYSTEM_PROMPT = `Bạn là FinBot - một người bạn thân am hiểu tài chính, không phải robot hay trợ lý AI cứng nhắc.

TÍNH CÁCH CỦA BẠN:
- Nói chuyện như bạn bè thân, thoải mái, vui vẻ
- Dùng ngôn ngữ đời thường, có thể dùng tiếng lóng nhẹ (oke, ngon, xịn, chill...)
- Đôi khi đùa nhẹ, trêu chọc vui vẻ khi phù hợp
- Thấu hiểu và đồng cảm khi người dùng gặp khó khăn tài chính
- Không giảng đạo, không phán xét thói quen chi tiêu
- Khen ngợi khi họ làm tốt, động viên khi họ cần
- Trả lời ngắn gọn, không dài dòng
- KHÔNG DÙNG EMOJI - chỉ dùng text thuần

CÁCH NÓI CHUYỆN:
- Thay vì "Tôi" → dùng "mình" hoặc "tớ"
- Thay vì "Bạn" → dùng "bạn", "cậu", hoặc tên nếu biết
- Có thể dùng: "nha", "nhé", "á", "đó", "hen"
- Ví dụ: "Oke ghi rồi nha!", "Xịn đấy!", "Chill thôi, từ từ tính"

⚠️ QUY TẮC QUAN TRỌNG VỀ SỐ DƯ:
- LUÔN LUÔN sử dụng số liệu từ "DỮ LIỆU TÀI CHÍNH CỦA NGƯỜI DÙNG" được cung cấp trong context
- KHÔNG TỰ Ý tính toán hoặc cộng dồn số dư từ lịch sử chat
- Khi user hỏi "số dư hiện tại", "còn lại bao nhiêu", "balance" → trả lời CHÍNH XÁC số "Còn lại" trong dữ liệu context
- TUYỆT ĐỐI KHÔNG nhớ hoặc tham khảo số dư từ tin nhắn trước đó
- Nếu không có dữ liệu context, nói rõ "Mình chưa có dữ liệu, cậu cho mình biết thu nhập và chi tiêu nhé"

VÍ DỤ ĐÚNG:
User: "số dư hiện tại?"
Context: "Còn lại: 4.805.000đ"
Bot: "Số dư hiện tại của cậu là 4.805.000đ."

VÍ DỤ SAI (TUYỆT ĐỐI TRÁNH):
User: "số dư hiện tại?"
Bot: "Cậu vừa nhận 1tr, trước đó có 5tr, nên bây giờ là 6tr" ❌ SAI - KHÔNG TỰ TÍNH

${FINANCE_KNOWLEDGE}

KHẢ NĂNG:
1. Tư vấn quản lý chi tiêu, tiết kiệm
2. Giải đáp thắc mắc tài chính
3. Gợi ý cách tiết kiệm, đầu tư
4. Ghi nhận giao dịch thu chi

KHI GHI GIAO DỊCH:
Nhận diện: "ghi", "thêm", "mua", "tiêu", "chi", "nhận lương", "thu nhập", hoặc chỉ nói số tiền + mục đích

FORMAT (ẩn với user):
[CREATE_TRANSACTION]
{"action": "create_transaction", "type": "expense", "amount": 50000, "category": "Ăn uống", "description": "Mô tả"}
[/CREATE_TRANSACTION]

DANH MỤC:
- Chi tiêu: "Ăn uống", "Di chuyển", "Mua sắm", "Giải trí", "Sức khỏe", "Giáo dục", "Hóa đơn", "Khác"
- Thu nhập: "Lương", "Thưởng", "Đầu tư", "Khác"

VÍ DỤ HỘI THOẠI TỰ NHIÊN:

User: "50k cafe"
Bot:
[CREATE_TRANSACTION]
{"action": "create_transaction", "type": "expense", "amount": 50000, "category": "Ăn uống", "description": "Cafe"}
[/CREATE_TRANSACTION]
Ghi rồi nha, 50k cafe.

User: "vừa thua tài xỉu 500k"
Bot:
[CREATE_TRANSACTION]
{"action": "create_transaction", "type": "expense", "amount": 500000, "category": "Giải trí", "description": "Tài xỉu"}
[/CREATE_TRANSACTION]
Ối, ghi rồi 500k. Lần sau chill lại nha, đỏ đen mà, hên xui thôi.

User: "lương 15tr"
Bot:
[CREATE_TRANSACTION]
{"action": "create_transaction", "type": "income", "amount": 15000000, "category": "Lương", "description": "Lương tháng"}
[/CREATE_TRANSACTION]
Nice, 15 triệu vào túi rồi! Nhớ để dành khoảng 3 triệu tiết kiệm nha.

User: "tháng này tiêu nhiều quá"
Bot: Chill đi, ai cũng có lúc vậy mà. Hay là mình cùng đặt mục tiêu tháng sau giảm bớt nhé?

User: "làm sao tiết kiệm được"
Bot: Mình hay làm thế này nè:
- Đầu tháng nhận lương, chuyển ngay 20% vào tài khoản khác, coi như không có
- Nấu cơm mang đi làm, tiết kiệm được 2-3 triệu/tháng luôn á
- Trước khi mua gì, đợi 24h xem còn muốn không

Cậu đang khó ở chỗ nào nhất?

User: "oke thanks"
Bot: Không có gì, cần gì cứ hú mình nha!

QUY TẮC CHUYỂN ĐỔI SỐ TIỀN:
- "k" hoặc "K" = nghìn (x1,000): "50k" = 50000
- "tr" hoặc "triệu" hoặc "chẹo" hoặc "trịu" = triệu (x1,000,000): "1tr" = 1000000, "30tr" = 30000000
- "củ" = triệu: "5 củ" = 5000000
- "tỷ" = tỷ (x1,000,000,000)

LƯU Ý QUAN TRỌNG:
- TUYỆT ĐỐI KHÔNG DÙNG EMOJI trong câu trả lời
- Nếu thiếu thông tin, hỏi ngắn gọn tự nhiên
- Đưa lời khuyên thực tế, không lý thuyết suông`;



/**
 * Lấy dữ liệu tài chính của user để cung cấp context cho AI
 */
async function getUserFinancialContext(userId) {
  if (!userId) return null;

  try {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, 1).toISOString().split('T')[0];

    // Lấy giao dịch tháng này
    const { data: thisMonthTx } = await supabase
      .from('transactions')
      .select('amount, type, categories(name)')
      .eq('user_id', userId)
      .gte('transaction_date', startOfMonth);

    // Lấy giao dịch 3 tháng gần đây
    const { data: recentTx } = await supabase
      .from('transactions')
      .select('amount, type, categories(name), transaction_date')
      .eq('user_id', userId)
      .gte('transaction_date', threeMonthsAgo)
      .order('transaction_date', { ascending: false });

    // Tính toán
    const thisMonthIncome = thisMonthTx?.filter(t => t.type === 'income').reduce((s, t) => s + parseFloat(t.amount), 0) || 0;
    const thisMonthExpense = thisMonthTx?.filter(t => t.type === 'expense').reduce((s, t) => s + parseFloat(t.amount), 0) || 0;

    // Chi tiêu theo danh mục tháng này
    const expenseByCategory = {};
    thisMonthTx?.filter(t => t.type === 'expense').forEach(t => {
      const cat = t.categories?.name || 'Khác';
      expenseByCategory[cat] = (expenseByCategory[cat] || 0) + parseFloat(t.amount);
    });

    // Top 5 danh mục chi tiêu
    const topCategories = Object.entries(expenseByCategory)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([name, amount]) => `${name}: ${formatVND(amount)}`);

    // Tính trung bình 3 tháng
    const totalExpense3m = recentTx?.filter(t => t.type === 'expense').reduce((s, t) => s + parseFloat(t.amount), 0) || 0;
    const avgMonthlyExpense = totalExpense3m / 3;

    return {
      thisMonth: {
        income: thisMonthIncome,
        expense: thisMonthExpense,
        balance: thisMonthIncome - thisMonthExpense
      },
      topCategories,
      avgMonthlyExpense,
      transactionCount: recentTx?.length || 0
    };
  } catch (error) {
    console.error('Error getting user financial context:', error);
    return null;
  }
}

function formatVND(amount) {
  return new Intl.NumberFormat('vi-VN').format(amount) + 'đ';
}

/**
 * Parse user message để tìm giao dịch
 * Ví dụ: "50k cafe", "lương 15tr", "chi 100k ăn trưa"
 */
function parseUserMessage(message) {
  if (!message) return null;
  
  const text = message.toLowerCase();
  
  // Kiểm tra có phải là message giao dịch không
  const hasAmount = /\d+\s*(k|K|tr|triệu|củ|nghìn|ngàn|m|M|\d{4,})/.test(message);
  if (!hasAmount) return null;
  
  // Xác định loại giao dịch
  let type = 'expense';
  if (/lương|thu nhập|nhận|thưởng|bonus|salary|income|tiền về|chuyển khoản đến|nhận được|có \d|được \d|kiếm được|thu về/.test(text)) {
    type = 'income';
  }
  
  // Parse số tiền
  let amount = 0;
  
  // Pattern: 50k, 50K, 50 nghìn, 50 ngàn
  const kPattern = /(\d+(?:[.,]\d+)?)\s*(?:k|K|nghìn|ngàn)/;
  // Pattern: 1tr, 1 triệu, 1m, 1 củ
  const trPattern = /(\d+(?:[.,]\d+)?)\s*(?:tr|triệu|m|M|củ)/i;
  // Pattern: số thuần lớn (50000+)
  const numPattern = /(\d{4,})/;

  if (trPattern.test(message)) {
    const match = message.match(trPattern);
    amount = parseFloat(match[1].replace(',', '.')) * 1000000;
  } else if (kPattern.test(message)) {
    const match = message.match(kPattern);
    amount = parseFloat(match[1].replace(',', '.')) * 1000;
  } else if (numPattern.test(message)) {
    const match = message.match(numPattern);
    amount = parseFloat(match[1]);
  }
  
  if (amount <= 0) return null;
  
  // Xác định category
  let category = type === 'income' ? 'Lương' : 'Khác';
  
  const categoryKeywords = {
    'ăn|uống|cafe|cà phê|trưa|tối|sáng|cơm|phở|bún|bánh|đồ ăn|food': 'Ăn uống',
    'grab|taxi|xăng|xe|gojek|be|uber|di chuyển|đi lại': 'Di chuyển',
    'mua|shopping|quần|áo|giày|dép|đồ|order': 'Mua sắm',
    'game|phim|netflix|spotify|giải trí|chơi|tài xỉu|cá độ|đánh bài': 'Giải trí',
    'thuốc|bệnh|viện|khám|sức khỏe|doctor': 'Sức khỏe',
    'học|sách|khóa|course|giáo dục': 'Giáo dục',
    'điện|nước|internet|wifi|hóa đơn|bill': 'Hóa đơn',
    'nhà|thuê|rent': 'Nhà cửa',
    'lương|salary': 'Lương',
    'thưởng|bonus': 'Thưởng',
  };
  
  for (const [keywords, catName] of Object.entries(categoryKeywords)) {
    const regex = new RegExp(keywords, 'i');
    if (regex.test(text)) {
      category = catName;
      break;
    }
  }
  
  // Tạo description từ message (bỏ số tiền)
  let description = message
    .replace(/\d+(?:[.,]\d+)?\s*(?:k|K|nghìn|ngàn|tr|triệu|m|M|củ)?/gi, '')
    .replace(/chi|tiêu|mua|ghi|thêm|lương|thu nhập/gi, '')
    .trim();
  
  if (!description || description.length < 2) {
    description = category;
  }
  
  return {
    action: 'create_transaction',
    type,
    amount,
    category,
    description
  };
}

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

    // Lấy dữ liệu tài chính của user
    const financialContext = await getUserFinancialContext(userId);
    
    // 🔍 DEBUG LOG
    if (financialContext) {
      console.log('💰 Financial Context:', {
        income: financialContext.thisMonth.income,
        expense: financialContext.thisMonth.expense,
        balance: financialContext.thisMonth.balance
      });
    }
    
    // Tạo context message nếu có dữ liệu
    let userContextPrompt = '';
    if (financialContext && financialContext.transactionCount > 0) {
      userContextPrompt = `
DỮ LIỆU TÀI CHÍNH CỦA NGƯỜI DÙNG (tháng này - CẬP NHẬT MỚI NHẤT):
- Thu nhập: ${formatVND(financialContext.thisMonth.income)}
- Chi tiêu: ${formatVND(financialContext.thisMonth.expense)}
- Còn lại: ${formatVND(financialContext.thisMonth.balance)}
- Chi tiêu TB/tháng (3 tháng): ${formatVND(financialContext.avgMonthlyExpense)}
- Top chi tiêu: ${financialContext.topCategories.join(', ') || 'Chưa có'}

⚠️ QUAN TRỌNG: Đây là dữ liệu THỰC TẾ từ database. Khi user hỏi về số dư, thu nhập, chi tiêu - HÃY DÙNG CHÍNH XÁC các con số này, KHÔNG tự tính toán từ lịch sử chat.
`;
    }

    // Lấy hoặc tạo conversation history
    const historyKey = conversationId || `${userId || 'anon'}-${Date.now()}`;
    let history = conversationHistory.get(historyKey) || [];

    // ✨ KIỂM TRA: Nếu user hỏi về số dư/tài chính, XÓA HISTORY để tránh AI nhầm lẫn
    const isFinancialQuery = /số dư|còn lại|balance|bao nhiêu|hiện tại|tổng|thu nhập|chi tiêu/i.test(message);
    if (isFinancialQuery && financialContext) {
      console.log('🔄 Financial query detected - clearing history to prevent AI confusion');
      history = []; // Xóa history để AI chỉ dựa vào dữ liệu thực
    }

    // Thêm tin nhắn user vào history
    history.push({
      role: 'user',
      content: message
    });

    // Giới hạn history
    if (history.length > 20) {
      history = history.slice(-20);
    }

    // Gọi Groq API với context tài chính
    const systemPromptWithContext = userContextPrompt 
      ? SYSTEM_PROMPT + '\n\n' + userContextPrompt 
      : SYSTEM_PROMPT;

    const completion = await groq.chat.completions.create({
      model: 'llama-3.3-70b-versatile',
      messages: [
        { role: 'system', content: systemPromptWithContext },
        ...history
      ],
      temperature: 0.7,
      max_tokens: 1024,
    });

    let aiResponse = completion.choices[0]?.message?.content || 'Xin lỗi, tôi không thể trả lời lúc này.';

    // ✨ KIỂM TRA VÀ SỬA LỖI: Nếu user hỏi về số dư, đảm bảo AI trả lời đúng
    if (isFinancialQuery && financialContext) {
      const correctBalance = formatVND(financialContext.thisMonth.balance);
      const correctIncome = formatVND(financialContext.thisMonth.income);
      const correctExpense = formatVND(financialContext.thisMonth.expense);
      
      // Nếu AI đề cập số dư nhưng không chính xác, sửa lại
      const balancePattern = /số dư.*?(\d[\d.,\s]*(?:triệu|tr|nghìn|k|đ))/i;
      const match = aiResponse.match(balancePattern);
      
      if (match && !aiResponse.includes(correctBalance)) {
        console.log('⚠️ AI response contains incorrect balance, correcting...');
        // Thay thế bằng số dư chính xác
        aiResponse = `Số dư hiện tại của cậu là ${correctBalance} (thu nhập ${correctIncome}, chi tiêu ${correctExpense}).`;
      } else if (/số dư|còn lại|balance/i.test(message) && !match) {
        // User hỏi số dư nhưng AI không trả lời rõ ràng
        aiResponse = `Số dư hiện tại của cậu là ${correctBalance}.`;
      }
    }

    // Kiểm tra và xử lý lệnh tạo giao dịch
    let transactionCreated = null;
    const transactionMatch = aiResponse.match(/\[CREATE_TRANSACTION\]([\s\S]*?)\[\/CREATE_TRANSACTION\]/);
    
    // Nếu AI không tạo transaction block, thử parse từ message user
    let transactionData = null;
    
    if (transactionMatch) {
      try {
        transactionData = JSON.parse(transactionMatch[1].trim());
      } catch (e) {
        console.log('Failed to parse AI transaction block:', e);
      }
    }
    
    // Fallback: Parse trực tiếp từ user message nếu có dấu hiệu giao dịch
    if (!transactionData && userId) {
      const parsed = parseUserMessage(message);
      if (parsed && parsed.amount > 0) {
        transactionData = parsed;
        console.log('Parsed from user message:', transactionData);
      }
    }
    
    if (transactionData && transactionData.amount > 0 && userId) {
      try {
        // Tìm category ID
        const { data: categories } = await supabase
          .from('categories')
          .select('id, name, type')
          .eq('user_id', userId);
        
        let categoryId = null;
        const categoryName = transactionData.category || 'Khác';
        const txType = transactionData.type || 'expense';
        
        // Tìm category phù hợp (cùng type)
        const matchedCategory = categories?.find(c => 
          c.type === txType && (
            c.name.toLowerCase().includes(categoryName.toLowerCase()) ||
            categoryName.toLowerCase().includes(c.name.toLowerCase())
          )
        );
        
        if (matchedCategory) {
          categoryId = matchedCategory.id;
        } else {
          // Tìm category "Khác" hoặc "Lương" theo type
          const fallbackName = txType === 'income' ? 'Lương' : 'Khác';
          const fallbackCat = categories?.find(c => c.type === txType && c.name === fallbackName);
          if (fallbackCat) {
            categoryId = fallbackCat.id;
          } else {
            // Tạo category mới nếu chưa có
            const { data: newCat } = await supabase
              .from('categories')
              .insert({
                user_id: userId,
                name: categoryName,
                type: txType,
                icon: txType === 'income' ? '💰' : '📝',
                color: txType === 'income' ? '#2ECC71' : '#808080'
              })
              .select()
              .single();
            categoryId = newCat?.id;
          }
        }

        if (categoryId) {
            // Tạo giao dịch
            const { data: transaction, error } = await supabase
              .from('transactions')
              .insert({
                user_id: userId,
                category_id: categoryId,
                amount: transactionData.amount,
                type: txType,
                description: transactionData.description || '',
                transaction_date: new Date().toISOString().split('T')[0]
              })
              .select()
              .single();

            if (!error && transaction) {
              transactionCreated = {
                id: transaction.id,
                amount: transactionData.amount,
                type: txType,
                category: categoryName,
                description: transactionData.description
              };
              console.log('✅ Transaction created:', transactionCreated);
              
              // ✨ CẬP NHẬT: Fetch lại dữ liệu tài chính sau khi tạo giao dịch
              const updatedContext = await getUserFinancialContext(userId);
              if (updatedContext) {
                // Thêm thông tin số dư mới vào response
                const newBalance = updatedContext.thisMonth.balance;
                const oldBalance = financialContext?.thisMonth?.balance || 0;
                
                // Nếu AI chưa đề cập đến số dư mới, thêm vào
                if (!aiResponse.includes(formatVND(newBalance))) {
                  if (txType === 'income') {
                    aiResponse += `\n\nSố dư mới của cậu là ${formatVND(newBalance)}.`;
                  } else {
                    aiResponse += `\n\nSố dư còn lại: ${formatVND(newBalance)}.`;
                  }
                }
                
                // ✨ XÓA HISTORY để tránh AI nhầm lẫn số dư cũ
                // Chỉ giữ lại 2 tin nhắn cuối (user message + bot response hiện tại)
                history = history.slice(-1); // Giữ user message cuối
              }
            } else {
              console.error('❌ Failed to create transaction:', error);
            }
          }
      } catch (parseError) {
        console.error('❌ Failed to process transaction:', parseError);
      }

      // Xóa phần JSON khỏi response để user không thấy
      aiResponse = aiResponse.replace(/\[CREATE_TRANSACTION\][\s\S]*?\[\/CREATE_TRANSACTION\]/, '').trim();
    }

    // Nếu không có userId nhưng AI muốn tạo giao dịch
    if (transactionMatch && !userId) {
      aiResponse = aiResponse.replace(/\[CREATE_TRANSACTION\][\s\S]*?\[\/CREATE_TRANSACTION\]/, '').trim();
      aiResponse += '\n\nBạn cần đăng nhập để tôi có thể ghi chi tiêu cho bạn.';
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
