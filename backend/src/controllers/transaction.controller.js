const supabase = require('../config/supabase');

exports.getAll = async (req, res) => {
  try {
    const { startDate, endDate, type, categoryId, limit = 50, offset = 0 } = req.query;

    let query = supabase
      .from('transactions')
      .select('*, categories(name, icon, color)')
      .eq('user_id', req.user.id)
      .order('transaction_date', { ascending: false })
      .range(offset, offset + limit - 1);

    if (startDate) query = query.gte('transaction_date', startDate);
    if (endDate) query = query.lte('transaction_date', endDate);
    if (type) query = query.eq('type', type);
    if (categoryId) query = query.eq('category_id', categoryId);

    const { data, error } = await query;

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.getById = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from('transactions')
      .select('*, categories(name, icon, color)')
      .eq('id', id)
      .eq('user_id', req.user.id)
      .single();

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(404).json({ error: 'Transaction not found' });
  }
};

exports.create = async (req, res) => {
  try {
    const { categoryId, amount, type, description, transactionDate } = req.body;

    const { data, error } = await supabase
      .from('transactions')
      .insert({
        user_id: req.user.id,
        category_id: categoryId,
        amount,
        type,
        description,
        transaction_date: transactionDate || new Date().toISOString().split('T')[0]
      })
      .select('*, categories(name, icon, color)')
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.update = async (req, res) => {
  try {
    const { id } = req.params;
    const { categoryId, amount, type, description, transactionDate } = req.body;

    const { data, error } = await supabase
      .from('transactions')
      .update({
        category_id: categoryId,
        amount,
        type,
        description,
        transaction_date: transactionDate
      })
      .eq('id', id)
      .eq('user_id', req.user.id)
      .select('*, categories(name, icon, color)')
      .single();

    if (error) throw error;
    res.json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.delete = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabase
      .from('transactions')
      .delete()
      .eq('id', id)
      .eq('user_id', req.user.id);

    if (error) throw error;
    res.json({ message: 'Transaction deleted' });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

exports.createFromOCR = async (req, res) => {
  try {
    const { ocrData, categoryId, transactionDate } = req.body;
    // ocrData: { rawText, extractedAmount, extractedItems }

    const { data, error } = await supabase
      .from('transactions')
      .insert({
        user_id: req.user.id,
        category_id: categoryId,
        amount: ocrData.extractedAmount,
        type: 'expense',
        description: ocrData.extractedItems?.join(', ') || 'OCR Import',
        transaction_date: transactionDate || new Date().toISOString().split('T')[0],
        ocr_data: ocrData
      })
      .select('*, categories(name, icon, color)')
      .single();

    if (error) throw error;
    res.status(201).json(data);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

/**
 * Parse voice input bằng AI
 * Input: "Chi 50k ăn trưa" hoặc "Thu nhập 10 triệu lương"
 */
exports.parseVoice = async (req, res) => {
  try {
    const { text } = req.body;
    const userId = req.user.id;

    // Lấy danh mục của user
    const { data: categories } = await supabase
      .from('categories')
      .select('id, name, type')
      .eq('user_id', userId);

    // Parse bằng regex trước
    const parsed = parseVietnameseTransaction(text, categories);

    res.json(parsed);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

/**
 * Parse SMS banking messages
 */
exports.parseSms = async (req, res) => {
  try {
    const { messages } = req.body;
    const userId = req.user.id;

    // Lấy danh mục
    const { data: categories } = await supabase
      .from('categories')
      .select('id, name, type')
      .eq('user_id', userId);

    const parsed = [];

    for (const sms of messages) {
      const result = parseBankingSms(sms.body, categories);
      if (result) {
        parsed.push({
          ...result,
          originalSms: sms.body,
          date: sms.date
        });
      }
    }

    res.json(parsed);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

/**
 * Helper: Parse text tiếng Việt thành transaction
 */
function parseVietnameseTransaction(text, categories) {
  const lowerText = text.toLowerCase();
  
  // Xác định loại giao dịch
  let type = 'expense';
  if (lowerText.includes('thu') || lowerText.includes('nhận') || lowerText.includes('lương')) {
    type = 'income';
  }

  // Parse số tiền
  let amount = 0;
  
  // Pattern: 50k, 50K, 50 nghìn, 50 ngàn
  const kPattern = /(\d+(?:[.,]\d+)?)\s*(?:k|K|nghìn|ngàn)/;
  // Pattern: 1tr, 1 triệu, 1m
  const trPattern = /(\d+(?:[.,]\d+)?)\s*(?:tr|triệu|m|M)/;
  // Pattern: số thuần (50000)
  const numPattern = /(\d{4,})/;

  if (trPattern.test(text)) {
    const match = text.match(trPattern);
    amount = parseFloat(match[1].replace(',', '.')) * 1000000;
  } else if (kPattern.test(text)) {
    const match = text.match(kPattern);
    amount = parseFloat(match[1].replace(',', '.')) * 1000;
  } else if (numPattern.test(text)) {
    const match = text.match(numPattern);
    amount = parseFloat(match[1]);
  }

  // Tìm danh mục phù hợp
  let categoryId = null;
  let categoryName = 'Khác';
  
  const categoryKeywords = {
    'ăn': ['Ăn uống', 'ăn uống'],
    'uống': ['Ăn uống', 'ăn uống'],
    'cafe': ['Ăn uống', 'Cafe'],
    'cà phê': ['Ăn uống', 'Cafe'],
    'trưa': ['Ăn uống'],
    'tối': ['Ăn uống'],
    'sáng': ['Ăn uống'],
    'grab': ['Di chuyển'],
    'taxi': ['Di chuyển'],
    'xăng': ['Di chuyển'],
    'xe': ['Di chuyển'],
    'điện': ['Hóa đơn'],
    'nước': ['Hóa đơn'],
    'internet': ['Hóa đơn'],
    'wifi': ['Hóa đơn'],
    'nhà': ['Nhà cửa', 'Hóa đơn'],
    'thuê': ['Nhà cửa'],
    'mua': ['Mua sắm'],
    'shopping': ['Mua sắm'],
    'quần': ['Mua sắm'],
    'áo': ['Mua sắm'],
    'lương': ['Lương'],
    'thưởng': ['Thưởng'],
    'game': ['Giải trí'],
    'phim': ['Giải trí'],
    'thuốc': ['Sức khỏe'],
    'bệnh': ['Sức khỏe'],
    'học': ['Giáo dục'],
    'sách': ['Giáo dục'],
  };

  for (const [keyword, catNames] of Object.entries(categoryKeywords)) {
    if (lowerText.includes(keyword)) {
      for (const catName of catNames) {
        const found = categories.find(c => 
          c.name.toLowerCase() === catName.toLowerCase() && c.type === type
        );
        if (found) {
          categoryId = found.id;
          categoryName = found.name;
          break;
        }
      }
      if (categoryId) break;
    }
  }

  // Fallback to "Khác"
  if (!categoryId) {
    const fallback = categories.find(c => c.name === 'Khác' && c.type === type);
    if (fallback) {
      categoryId = fallback.id;
      categoryName = 'Khác';
    }
  }

  // Tạo mô tả
  const description = text.replace(/\d+(?:[.,]\d+)?\s*(?:k|K|nghìn|ngàn|tr|triệu|m|M)?/g, '').trim();

  return {
    type,
    amount,
    categoryId,
    categoryName,
    description: description || text
  };
}

/**
 * Helper: Parse SMS ngân hàng
 */
function parseBankingSms(smsBody, categories) {
  if (!smsBody) return null;

  const text = smsBody.toLowerCase();
  
  // Patterns cho các ngân hàng phổ biến
  // VCB: "GD: -500,000 VND ... SD: 1,000,000 VND"
  // TCB: "So tien GD: 500,000 VND"
  // MB: "GD -500,000d"
  
  let amount = 0;
  let type = 'expense';

  // Pattern tìm số tiền
  const amountPatterns = [
    /(?:GD|giao dịch|so tien|số tiền)[:\s]*([+-]?)[\s]*([\d,\.]+)\s*(?:VND|đ|d)/i,
    /([+-])([\d,\.]+)\s*(?:VND|đ|d)/i,
    /([\d,\.]+)\s*(?:VND|đ|d)/i,
  ];

  for (const pattern of amountPatterns) {
    const match = smsBody.match(pattern);
    if (match) {
      const sign = match[1];
      const numStr = match[2] || match[1];
      amount = parseFloat(numStr.replace(/[,\.]/g, ''));
      
      if (sign === '+' || text.includes('nhận') || text.includes('cộng')) {
        type = 'income';
      }
      break;
    }
  }

  if (amount === 0) return null;

  // Tìm category
  let categoryId = null;
  let categoryName = 'Khác';
  
  const fallback = categories.find(c => c.name === 'Khác' && c.type === type);
  if (fallback) {
    categoryId = fallback.id;
  }

  return {
    type,
    amount,
    categoryId,
    categoryName,
    description: `SMS Banking: ${smsBody.substring(0, 50)}...`
  };
}
