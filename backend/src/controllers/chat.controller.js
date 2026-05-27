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
- Luôn gọi người dùng là "bạn". KHÔNG dùng "cậu" trong mọi câu trả lời
- Có thể dùng: "nha", "nhé", "á", "đó", "hen"
- Ví dụ: "Oke ghi rồi nha!", "Xịn đấy!", "Chill thôi, từ từ tính"
- Khi user hỏi "bạn là ai", "cậu là ai", "bạn tên gì" → trả lời thật ngắn, tự nhiên. Ví dụ: "Mình là FinBot, bạn đồng hành giúp bạn theo dõi chi tiêu và quản lý tiền. Cần gì về tiền bạc cứ hỏi mình nha."
- Không tự giới thiệu dài dòng, không nói kiểu quảng cáo, không nhấn mạnh "không phải robot/trợ lý AI" trong câu trả lời.

⚠️ QUY TẮC QUAN TRỌNG VỀ SỐ DƯ:
- LUÔN LUÔN sử dụng số liệu từ "DỮ LIỆU TÀI CHÍNH CỦA NGƯỜI DÙNG" được cung cấp trong context
- KHÔNG TỰ Ý tính toán hoặc cộng dồn số dư từ lịch sử chat
- Khi user hỏi "số dư hiện tại", "còn lại bao nhiêu", "balance" → trả lời CHÍNH XÁC số "Còn lại" trong dữ liệu context
- TUYỆT ĐỐI KHÔNG nhớ hoặc tham khảo số dư từ tin nhắn trước đó
- Nếu không có dữ liệu context, nói rõ "Mình chưa có dữ liệu, bạn cho mình biết thu nhập và chi tiêu nhé"
- Nếu user hỏi cách chi tiêu/lập kế hoạch với số tiền còn lại đến cuối tháng → KHÔNG chỉ nhắc lại số dư. Hãy chia ngân sách theo số ngày còn lại, ưu tiên ăn uống/di chuyển/hóa đơn cần thiết, đưa hạn mức/ngày và gợi ý khoản nên tránh.

VÍ DỤ ĐÚNG:
User: "số dư hiện tại?"
Context: "Còn lại: 4.805.000đ"
Bot: "Số dư hiện tại của bạn là 4.805.000đ."

VÍ DỤ SAI (TUYỆT ĐỐI TRÁNH):
User: "số dư hiện tại?"
Bot: "Bạn vừa nhận 1tr, trước đó có 5tr, nên bây giờ là 6tr" ❌ SAI - KHÔNG TỰ TÍNH

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

Bạn đang khó ở chỗ nào nhất?

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


async function getUserFinancialContext(userId) {
  if (!userId) return null;

  try {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    const threeMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 3, 1).toISOString().split('T')[0];

    const { data: thisMonthTx } = await supabase
      .from('transactions')
      .select('amount, type, categories(name)')
      .eq('user_id', userId)
      .gte('transaction_date', startOfMonth);

    const { data: recentTx } = await supabase
      .from('transactions')
      .select('amount, type, categories(name), transaction_date')
      .eq('user_id', userId)
      .gte('transaction_date', threeMonthsAgo)
      .order('transaction_date', { ascending: false });

    const thisMonthIncome = thisMonthTx?.filter(t => t.type === 'income').reduce((s, t) => s + parseFloat(t.amount), 0) || 0;
    const thisMonthExpense = thisMonthTx?.filter(t => t.type === 'expense').reduce((s, t) => s + parseFloat(t.amount), 0) || 0;

    const expenseByCategory = {};
    thisMonthTx?.filter(t => t.type === 'expense').forEach(t => {
      const cat = t.categories?.name || 'Khác';
      expenseByCategory[cat] = (expenseByCategory[cat] || 0) + parseFloat(t.amount);
    });

    const topCategories = Object.entries(expenseByCategory)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([name, amount]) => `${name}: ${formatVND(amount)}`);

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

function normalizeBotAddressing(text) {
  if (!text) return text;

  return text
    .replace(/\bCậu\b/g, 'Bạn')
    .replace(/\bcậu\b/g, 'bạn');
}

async function saveChatMessage(userId, conversationId, role, content, metadata = null) {
  if (!userId || !conversationId || !content) return;

  try {
    const { error } = await supabase
      .from('chat_history')
      .insert({
        user_id: userId,
        conversation_id: conversationId,
        role,
        content,
        metadata
      });

    if (error) {
      console.error('Failed to save chat history:', error.message);
    }
  } catch (error) {
    console.error('Failed to save chat history:', error.message);
  }
}

async function clearPersistedChatHistory(userId, conversationId) {
  if (!userId || !conversationId) return;

  try {
    const { error } = await supabase
      .from('chat_history')
      .delete()
      .eq('user_id', userId)
      .eq('conversation_id', conversationId);

    if (error) {
      console.error('Failed to clear chat history:', error.message);
    }
  } catch (error) {
    console.error('Failed to clear chat history:', error.message);
  }
}

function normalizeText(text) {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function isIdentityQuestion(message) {
  const text = normalizeText(message);
  if (text.length > 60) return false;

  return [
    'ban la ai',
    'cau la ai',
    'may la ai',
    'bot la ai',
    'finbot la ai',
    'ban ten gi',
    'cau ten gi',
    'ten ban la gi',
    'gioi thieu ban than'
  ].some(pattern => text === pattern || text.includes(pattern));
}

function isSpendingPlanQuestion(message) {
  const text = normalizeText(message);

  const hasPlanningIntent = /(\bnen\b|nhu the nao|lam sao|cach|ke hoach|phan bo|du tinh|sap xep|quan ly|chi tieu)/i.test(text);
  const hasRemainingMoneyContext = /(so tien con lai|tien con lai|con lai|so du|balance)/i.test(text);
  const hasTimeRange = /(den het thang|cuoi thang|het thang|thang nay|may ngay toi|tuan nay|05\/2026)/i.test(text);

  return hasPlanningIntent && (hasRemainingMoneyContext || hasTimeRange);
}

function isDirectBalanceQuestion(message) {
  const text = normalizeText(message);
  if (isSpendingPlanQuestion(message)) return false;

  const directPatterns = [
    /^so du( hien tai)?( cua (toi|minh|tui|em|anh|ban|cau))?( la)? bao nhieu$/,
    /^so du( hien tai)?$/,
    /^con lai bao nhieu( tien)?$/,
    /^minh con bao nhieu( tien)?$/,
    /^toi con bao nhieu( tien)?$/,
    /^balance$/,
    /^balance hien tai$/
  ];

  return directPatterns.some(pattern => pattern.test(text))
    || (/(so du|balance)/i.test(text) && /bao nhieu|hien tai/i.test(text))
    || (/con lai/i.test(text) && /bao nhieu/i.test(text) && !/nen|chi tieu|ke hoach|phan bo|den het thang|cuoi thang/i.test(text));
}

function isFinancialDataQuestion(message) {
  const text = normalizeText(message);
  if (isSpendingPlanQuestion(message)) return false;

  return isDirectBalanceQuestion(message)
    || (/(thu nhap|chi tieu|tong)/i.test(text) && /(bao nhieu|hien tai|thang nay)/i.test(text));
}

function getDaysRemainingInCurrentMonth() {
  const now = new Date();
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diffMs = endOfMonth - startToday;

  return Math.max(1, Math.floor(diffMs / (24 * 60 * 60 * 1000)) + 1);
}

function buildSpendingPlanResponse(financialContext) {
  const balance = financialContext?.thisMonth?.balance || 0;
  const daysRemaining = getDaysRemainingInCurrentMonth();
  const dailyBudget = Math.floor(balance / daysRemaining);
  const foodBudget = Math.floor(balance * 0.6);
  const transportBudget = Math.floor(balance * 0.25);
  const bufferBudget = balance - foodBudget - transportBudget;

  if (balance <= 0) {
    return 'Hiện tại bạn không còn dư trong tháng này, nên ưu tiên dừng các khoản không cần thiết trước nha. Nếu còn bắt buộc phải chi, mình nên ghi riêng từng khoản để biết cần bù từ đâu.';
  }

  return `Với ${formatVND(balance)} còn lại đến hết tháng, bạn nên giữ mức khoảng ${formatVND(dailyBudget)}/ngày trong ${daysRemaining} ngày tới.\n\nGợi ý chia nhanh:\n- Ăn uống/nhu yếu phẩm: khoảng ${formatVND(foodBudget)}\n- Di chuyển: khoảng ${formatVND(transportBudget)}\n- Dự phòng việc gấp: khoảng ${formatVND(bufferBudget)}\n\nTừ giờ đến cuối tháng nên hạn chế mua sắm, cafe/trà sữa, app đồ ăn và các khoản giải trí phát sinh. Mỗi ngày cứ nhìn mốc ${formatVND(dailyBudget)} mà canh, ngày nào chi ít hơn thì phần dư để bù cho ngày sau.`;
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

    if (isIdentityQuestion(message)) {
      const historyKey = conversationId || `${userId || 'anon'}-${Date.now()}`;
      const aiResponse = 'Mình là FinBot, bạn đồng hành giúp bạn theo dõi chi tiêu và quản lý tiền. Cần gì về tiền bạc cứ hỏi mình nha.';
      const history = conversationHistory.get(historyKey) || [];

      history.push({ role: 'user', content: message });
      history.push({ role: 'assistant', content: aiResponse });
      conversationHistory.set(historyKey, history.slice(-20));
      await saveChatMessage(userId, historyKey, 'user', message, { source: 'identity_question' });
      await saveChatMessage(userId, historyKey, 'assistant', aiResponse, { source: 'identity_question' });

      setTimeout(() => {
        conversationHistory.delete(historyKey);
      }, 60 * 60 * 1000);

      return res.json({
        success: true,
        data: {
          message: aiResponse,
          conversationId: historyKey,
          transactionCreated: null
        }
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
- Số ngày còn lại trong tháng (tính cả hôm nay): ${getDaysRemainingInCurrentMonth()} ngày
- Chi tiêu TB/tháng (3 tháng): ${formatVND(financialContext.avgMonthlyExpense)}
- Top chi tiêu: ${financialContext.topCategories.join(', ') || 'Chưa có'}

⚠️ QUAN TRỌNG: Đây là dữ liệu THỰC TẾ từ database. Khi user hỏi về số dư, thu nhập, chi tiêu - HÃY DÙNG CHÍNH XÁC các con số này, KHÔNG tự tính toán từ lịch sử chat.
`;
    }

    // Lấy hoặc tạo conversation history
    const historyKey = conversationId || `${userId || 'anon'}-${Date.now()}`;
    let history = conversationHistory.get(historyKey) || [];

    const isBalanceQuery = isDirectBalanceQuestion(message);
    const isFinancialQuery = isFinancialDataQuestion(message);
    const isSpendingPlanQuery = isSpendingPlanQuestion(message);

    // ✨ KIỂM TRA: Chỉ xóa history với câu hỏi số liệu trực tiếp để tránh AI nhầm số cũ.
    // Các câu xin tư vấn như "với số tiền còn lại đó nên chi tiêu thế nào" vẫn giữ history.
    if (isFinancialQuery && financialContext) {
      console.log('🔄 Financial data query detected - clearing history to prevent AI confusion');
      history = []; // Xóa history để AI chỉ dựa vào dữ liệu thực
    }

    // Thêm tin nhắn user vào history
    history.push({
      role: 'user',
      content: message
    });
    await saveChatMessage(userId, historyKey, 'user', message);

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
    if (isBalanceQuery && financialContext) {
      const correctBalance = formatVND(financialContext.thisMonth.balance);
      const correctIncome = formatVND(financialContext.thisMonth.income);
      const correctExpense = formatVND(financialContext.thisMonth.expense);
      
      // Nếu AI đề cập số dư nhưng không chính xác, sửa lại
      const balancePattern = /số dư.*?(\d[\d.,\s]*(?:triệu|tr|nghìn|k|đ))/i;
      const match = aiResponse.match(balancePattern);
      
      if (match && !aiResponse.includes(correctBalance)) {
        console.log('⚠️ AI response contains incorrect balance, correcting...');
        // Thay thế bằng số dư chính xác
        aiResponse = `Số dư hiện tại của bạn là ${correctBalance} (thu nhập ${correctIncome}, chi tiêu ${correctExpense}).`;
      } else if (!match) {
        // User hỏi số dư nhưng AI không trả lời rõ ràng
        aiResponse = `Số dư hiện tại của bạn là ${correctBalance}.`;
      }
    }

    if (isSpendingPlanQuery && financialContext) {
      const balanceOnlyResponse = /^số dư hiện tại của (bạn|cậu) là [\d.,\s]+đ\.?$/i.test(aiResponse.trim());
      if (balanceOnlyResponse) {
        console.log('⚠️ Spending plan query got balance-only response, replacing with plan...');
        aiResponse = buildSpendingPlanResponse(financialContext);
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
                    aiResponse += `\n\nSố dư mới của bạn là ${formatVND(newBalance)}.`;
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

    aiResponse = normalizeBotAddressing(aiResponse);

    // Thêm response vào history
    history.push({
      role: 'assistant',
      content: aiResponse
    });
    await saveChatMessage(userId, historyKey, 'assistant', aiResponse, {
      transactionCreated,
      isBalanceQuery,
      isSpendingPlanQuery
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
    const userId = req.user?.id;
    
    if (conversationId) {
      conversationHistory.delete(conversationId);
      await clearPersistedChatHistory(userId, conversationId);
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
