# Luồng Xử Lý AI Chatbot (FinBot)

Tài liệu này mô tả chi tiết luồng xử lý AI Chatbot trong ứng dụng, từ khi người dùng nhắn tin đến khi nhận phản hồi và tạo giao dịch.

---

## Sơ Đồ Tổng Quan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MOBILE APP (Flutter)                                 │
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────────────────────┐   │
│  │ User nhắn   │───▶│ ChatScreen   │───▶│ ChatService.sendMessage()   │   │
│  │ tin nhắn    │    │              │    │ (Gửi tin nhắn + token)     │   │
│  └──────────────┘    └──────────────┘    └───────────┬─────────────────┘   │
│                                                      │                       │
└───────────────────────────────────────────────────────│──────────────────────┘
                                                        │
                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND (Node.js)                                  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         Chat Controller                               │   │
│  │  ┌─────────────────┐    ┌──────────────────────────────────────────┐ │   │
│  │  │ /chat (POST)   │───▶│ 1. Lấy dữ liệu tài chính user từ DB    │ │   │
│  │  │                │    │ 2. Kiểm tra loại câu hỏi                │ │   │
│  │  │                │    │ 3. Lấy conversation history            │ │   │
│  │  │                │    │ 4. Gọi Groq API                        │ │   │
│  │  │                │    │ 5. Parse transaction (nếu có)          │ │   │
│  │  │                │    │ 6. Tạo transaction trong DB            │ │   │
│  │  │                │    └──────────────────────────────────────────┘ │   │
│  │  └─────────────────┘                                                 │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                      │                       │
└───────────────────────────────────────────────────────│──────────────────────┘
                                                        │
                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      GROQ API (LLM - Llama 3.3)                            │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                      SYSTEM PROMPT + USER CONTEXT                      │  │
│  │  ┌────────────────────────────────────────────────────────────────┐   │  │
│  │  │ • FINANCE_KNOWLEDGE (kiến thức tài chính VN)                   │   │  │
│  │  │ • SYSTEM_PROMPT (tính cách FinBot, cách nói chuyện)            │   │  │
│  │  │ • DỮ LIỆU TÀI CHÍNH CỦA NGƯỜI DÙNG (số dư, thu chi...)       │   │  │
│  │  │ • Conversation History (lịch sử chat)                          │   │  │
│  │  └────────────────────────────────────────────────────────────────┘   │  │
│  │                                    │                                    │  │
│  │                                    ▼                                    │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Groq Llama 3.3 70B                            │  │  │
│  │  │           (Xử lý + Trả về response có [CREATE_TRANSACTION])     │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                                │
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        KẾT QUẢ TRẢ VỀ                                     │
│                                                                             │
│  {                                                                       │
│    "success": true,                                                       │
│    "data": {                                                             │
│      "message": "Ghi rồi nha, 50k cafe.",                                │
│      "conversationId": "user-123-1699999999999",                          │
│      "transactionCreated": {                                              │
│        "id": "tx-456",                                                   │
│        "amount": 50000,                                                  │
│        "type": "expense",                                                │
│        "category": "Ăn uống"                                             │
│      }                                                                   │
│    }                                                                     │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Chi Tiết Từng Bước

### Bước 1: User Nhắn Tin (Mobile)

**File**: `mobile/lib/screens/chat_screen.dart` (dòng 93-153)

```dart
Future<void> _sendMessage([String? quickMessage]) async {
  final text = quickMessage ?? _controller.text.trim();
  if (text.isEmpty || _isLoading) return;

  setState(() {
    _messages.add(ChatMessage(content: text, isUser: true));
    _isLoading = true;
  });

  // Lấy auth token từ Supabase
  final session = Supabase.instance.client.auth.currentSession;
  final authToken = session?.accessToken;

  // Gửi tin nhắn
  final response = await ChatService.sendMessage(text, authToken: authToken);

  // Xử lý response
  setState(() {
    _messages.add(ChatMessage(
      content: response.message,
      isUser: false,
      isError: isError,
    ));
    _isLoading = false;
  });
}
```

**Quick Suggestions** (gợi ý nhanh):
- 💰 Tiết kiệm
- 📊 Phân tích chi tiêu
- 🎯 Lập ngân sách
- ⚡ Ghi nhanh

---

### Bước 2: Gửi Request Lên Backend

**File**: `mobile/lib/config/chat_service.dart` (dòng 30-76)

```dart
static Future<ChatResponse> sendMessage(String message, {String? authToken}) async {
  final headers = <String, String>{};
  if (authToken != null) {
    headers['Authorization'] = 'Bearer $authToken';
  }

  final response = await _dio.post(
    '/chat',
    data: {
      'message': message,
      'conversationId': _conversationId,
    },
    options: Options(headers: headers),
  );

  if (response.data['success'] == true) {
    _conversationId = response.data['data']['conversationId'];
    return ChatResponse(
      message: response.data['data']['message'],
      conversationId: _conversationId,
      transactionCreated: response.data['data']['transactionCreated'],
    );
  }
}
```

---

### Bước 3: Xử Lý Ở Backend - Lấy Dữ Liệu Tài Chính

**File**: `backend/src/controllers/chat.controller.js` (dòng 164-216)

```javascript
async function getUserFinancialContext(userId) {
  if (!userId) return null;

  // Lấy giao dịch tháng này
  const { data: thisMonthTx } = await supabase
    .from('transactions')
    .select('amount, type, categories(name)')
    .eq('user_id', userId)
    .gte('transaction_date', startOfMonth);

  // Tính toán
  const thisMonthIncome = thisMonthTx?.filter(t => t.type === 'income')
    .reduce((s, t) => s + parseFloat(t.amount), 0) || 0;
  const thisMonthExpense = thisMonthTx?.filter(t => t.type === 'expense')
    .reduce((s, t) => s + parseFloat(t.amount), 0) || 0;

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
}
```

---

### Bước 4: Kiểm Tra Loại Câu Hỏi

**File**: `backend/src/controllers/chat.controller.js` (dòng 281-333)

```javascript
// Kiểm tra câu hỏi nhận dạng
function isIdentityQuestion(message) {
  const patterns = ['ban la ai', 'cau la ai', 'ban ten gi', ...];
  return patterns.some(pattern => text.includes(pattern));
}

// Kiểm tra câu hỏi về số dư trực tiếp
function isDirectBalanceQuestion(message) {
  const patterns = [
    /^so du( hien tai)?( cua (toi|minh|tui|em))?( la)? bao nhieu$/,
    /^con lai bao nhieu( tien)?$/,
    /^balance$/
  ];
  return directPatterns.some(pattern => pattern.test(text));
}

// Kiểm tra câu hỏi về kế hoạch chi tiêu
function isSpendingPlanQuestion(message) {
  const hasPlanningIntent = /(\bnen\b|nhu the nao|lam sao|cach|ke hoach)/i.test(text);
  const hasRemainingMoneyContext = /(so tien con lai|tien con lai|con lai)/i.test(text);
  return hasPlanningIntent && (hasRemainingMoneyContext || hasTimeRange);
}
```

---

### Bước 5: Xây Dựng Context Prompt

**File**: `backend/src/controllers/chat.controller.js` (dòng 497-509)

```javascript
let userContextPrompt = '';
if (financialContext && financialContext.transactionCount > 0) {
  userContextPrompt = `
DỮ LIỆU TÀI CHÍNH CỦA NGƯỜI DÙNG (tháng này - CẬP NHẬT MỚI NHẤT):
- Thu nhập: ${formatVND(financialContext.thisMonth.income)}
- Chi tiêu: ${formatVND(financialContext.thisMonth.expense)}
- Còn lại: ${formatVND(financialContext.thisMonth.balance)}
- Số ngày còn lại trong tháng: ${getDaysRemainingInCurrentMonth()} ngày
- Chi tiêu TB/tháng (3 tháng): ${formatVND(financialContext.avgMonthlyExpense)}
- Top chi tiêu: ${financialContext.topCategories.join(', ') || 'Chưa có'}

⚠️ QUAN TRỌNG: Đây là dữ liệu THỰC TẾ từ database.
`;
}
```

---

### Bước 6: Gọi Groq API

**File**: `backend/src/controllers/chat.controller.js` (dòng 539-552)

```javascript
const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY
});

// Gọi Groq API với Llama 3.3
const completion = await groq.chat.completions.create({
  model: 'llama-3.3-70b-versatile',
  messages: [
    { role: 'system', content: systemPromptWithContext },
    ...history  // Conversation history
  ],
  temperature: 0.7,
  max_tokens: 1024,
});

let aiResponse = completion.choices[0]?.message?.content || '...';
```

---

### Bước 7: Prompt Engineering - System Prompt

**File**: `backend/src/controllers/chat.controller.js` (dòng 58-161)

**FINANCE_KNOWLEDGE** - Kiến thức tài chính:
- Quy tắc 50/30/20
- Quy tắc 6 chiếc lọ
- Lãi suất & lạm phát VN
- Chi tiêu trung bình theo đối tượng
- Mẹo tiết kiệm

**SYSTEM_PROMPT** - Tính cách FinBot:
```javascript
"Bạn là FinBot - một người bạn thân am hiểu tài chính..."

TÍNH CÁCH:
- Nói chuyện như bạn bè thân
- Dùng ngôn ngữ đời thường
- KHÔNG DÙNG EMOJI
- Gọi user là "bạn"

QUY TẮC QUAN TRỌNG VỀ SỐ DƯ:
- LUÔN dùng số liệu từ DỮ LIỆU TÀI CHÍNH
- KHÔNG tự tính toán từ lịch sử chat
```

---

### Bước 8: Kiểm Tra & Sửa Lỗi Số Dư

**File**: `backend/src/controllers/chat.controller.js` (dòng 556-582)

```javascript
// Nếu user hỏi số dư, đảm bảo AI trả lời đúng
if (isBalanceQuery && financialContext) {
  const correctBalance = formatVND(financialContext.thisMonth.balance);
  const match = aiResponse.match(balancePattern);

  if (match && !aiResponse.includes(correctBalance)) {
    // Sửa số dư không chính xác
    aiResponse = `Số dư hiện tại của bạn là ${correctBalance}...`;
  } else if (!match) {
    // User hỏi số dư nhưng AI không trả lời rõ
    aiResponse = `Số dư hiện tại của bạn là ${correctBalance}.`;
  }
}
```

---

### Bước 9: Parse Transaction

**File**: `backend/src/controllers/chat.controller.js` (dòng 584-706)

```javascript
// Kiểm tra [CREATE_TRANSACTION] block
const transactionMatch = aiResponse.match(
  /\[CREATE_TRANSACTION\]([\s\S]*?)\[\/CREATE_TRANSACTION\]/
);

if (transactionMatch) {
  try {
    transactionData = JSON.parse(transactionMatch[1].trim());
  } catch (e) {
    console.log('Failed to parse AI transaction block:', e);
  }
}

// Fallback: Parse trực tiếp từ user message
if (!transactionData && userId) {
  const parsed = parseUserMessage(message);
  if (parsed && parsed.amount > 0) {
    transactionData = parsed;
  }
}
```

**Hàm parseUserMessage** (dòng 363-442):
```javascript
function parseUserMessage(message) {
  // Parse số tiền: "50k", "1tr", "15triệu"
  // Xác định type: income hay expense
  // Xác định category từ keywords
  // Tạo description
  return {
    action: 'create_transaction',
    type,
    amount,
    category,
    description
  };
}
```

---

### Bước 10: Tạo Transaction Trong Database

**File**: `backend/src/controllers/chat.controller.js` (dòng 608-704)

```javascript
if (transactionData && transactionData.amount > 0 && userId) {
  // 1. Tìm category ID
  const { data: categories } = await supabase
    .from('categories')
    .select('id, name, type')
    .eq('user_id', userId);

  // 2. Match category hoặc tạo mới
  let categoryId = matchedCategory?.id;
  if (!categoryId) {
    const { data: newCat } = await supabase
      .from('categories')
      .insert({
        user_id: userId,
        name: categoryName,
        type: txType,
        icon: '💰',
        color: '#2ECC71'
      })
      .select()
      .single();
    categoryId = newCat?.id;
  }

  // 3. Tạo transaction
  const { data: transaction, error } = await supabase
    .from('transactions')
    .insert({
      user_id: userId,
      category_id: categoryId,
      amount: transactionData.amount,
      type: txType,
      description: transactionData.description,
      transaction_date: new Date().toISOString().split('T')[0]
    })
    .select()
    .single();

  if (!error && transaction) {
    transactionCreated = {
      id: transaction.id,
      amount: transactionData.amount,
      type: txType,
      category: categoryName
    };
  }

  // 4. Cập nhật response với số dư mới
  const updatedContext = await getUserFinancialContext(userId);
  if (updatedContext && !aiResponse.includes(formatVND(updatedContext.thisMonth.balance))) {
    aiResponse += `\n\nSố dư còn lại: ${formatVND(updatedContext.thisMonth.balance)}.`;
  }
}
```

---

### Bước 11: Lưu History & Trả Về

**File**: `backend/src/controllers/chat.controller.js` (dòng 716-734)

```javascript
// Thêm response vào history
history.push({
  role: 'assistant',
  content: aiResponse
});

// Lưu vào Supabase
await saveChatMessage(userId, historyKey, 'assistant', aiResponse, {
  transactionCreated,
  isBalanceQuery,
  isSpendingPlanQuery
});

// Lưu vào memory (tự động xóa sau 1 giờ)
conversationHistory.set(historyKey, history);
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
```

---

## Cơ Chế Xử Lý Đặc Biệt

### 1. Conversation History

**In-Memory**: Lưu trong Map, tự động xóa sau 1 giờ
```javascript
const conversationHistory = new Map();
```

**Persisted**: Lưu vào Supabase table `chat_history`
```javascript
await saveChatMessage(userId, historyKey, 'user', message);
```

### 2. Kiểm Tra Loại Câu Hỏi

```
┌────────────────────────────────────────────────────────────┐
│              Câu hỏi nhận dạng ("bạn là ai?")             │
│                          │                                 │
│                          ▼                                 │
│         AI trả lời ngắn gọn, KHÔNG dùng Groq              │
│                          │                                 │
│                          ▼                                 │
│              Xóa history sau 1 phút                        │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│              Câu hỏi về số dư trực tiếp                    │
│                          │                                 │
│                          ▼                                 │
│        Xóa history → Lấy dữ liệu tài chính DB            │
│                          │                                 │
│                          ▼                                 │
│        Gọi Groq với context đã xóa history                │
│                          │                                 │
│                          ▼                                 │
│         AI trả lời với SỐ DƯ CHÍNH XÁC từ DB             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│              Câu hỏi tư vấn/kế hoạch chi tiêu             │
│                          │                                 │
│                          ▼                                 │
│        GIỮ history → Gọi Groq với context đầy đủ          │
│                          │                                 │
│                          ▼                                 │
│        AI trả lời tự nhiên với history                    │
└────────────────────────────────────────────────────────────┘
```

### 3. Auto-Correct Số Dư

```javascript
// Nếu AI trả lời SAI số dư → Tự động sửa
if (isBalanceQuery && financialContext) {
  const correctBalance = formatVND(financialContext.thisMonth.balance);

  // Nếu AI đề cập số dư nhưng không đúng
  if (match && !aiResponse.includes(correctBalance)) {
    aiResponse = `Số dư hiện tại của bạn là ${correctBalance}...`;
  }
}
```

---

## Ví Dụ Hội Thoại

### Ví dụ 1: Ghi Chi Tiêu

```
User: "50k cafe"
Bot: [CREATE_TRANSACTION]
{"action": "create_transaction", "type": "expense", "amount": 50000, "category": "Ăn uống", "description": "Cafe"}
[/CREATE_TRANSACTION]
Ghi rồi nha, 50k cafe. Số dư còn lại: 4.755.000đ.
```

### Ví dụ 2: Ghi Thu Nhập

```
User: "lương 15tr"
Bot: [CREATE_TRANSACTION]
{"action": "create_transaction", "type": "income", "amount": 15000000, "category": "Lương", "description": "Lương tháng"}
[/CREATE_TRANSACTION]
Nice, 15 triệu vào túi rồi! Số dư mới của bạn là 19.755.000đ. Nhớ để dành khoảng 3 triệu tiết kiệm nha.
```

### Ví dụ 3: Hỏi Số Dư

```
User: "số dư hiện tại?"
Context: "Còn lại: 4.805.000đ"
Bot: Số dư hiện tại của bạn là 4.805.000đ (thu nhập 10.000.000đ, chi tiêu 5.195.000đ).
```

### Ví dụ 4: Hỏi Kế Hoạch Chi Tiêu

```
User: "với số tiền còn lại đó nên chi tiêu thế nào đến cuối tháng?"
Bot: Với 4.805.000đ còn lại đến hết tháng (15 ngày), bạn nên giữ mức khoảng 320.000đ/ngày.

Gợi ý chia nhanh:
- Ăn uống/nhu yếu phẩm: khoảng 2.883.000đ
- Di chuyển: khoảng 1.201.000đ
- Dự phòng việc gấp: khoảng 721.000đ
```

---

## Cấu Trúc Dữ Liệu

### Request

```json
{
  "message": "50k cafe",
  "conversationId": "user-123-1699999999999"
}
```

### Response Thành Công

```json
{
  "success": true,
  "data": {
    "message": "Ghi rồi nha, 50k cafe. Số dư còn lại: 4.755.000đ.",
    "conversationId": "user-123-1699999999999",
    "transactionCreated": {
      "id": "tx-456",
      "amount": 50000,
      "type": "expense",
      "category": "Ăn uống",
      "description": "Cafe"
    }
  }
}
```

### Response Lỗi

```json
{
  "success": false,
  "error": "Rate limit exceeded"
}
```

---

## Các File Liên Quan

| File | Mô tả |
|------|-------|
| `mobile/lib/screens/chat_screen.dart` | Giao diện chat (Flutter) |
| `mobile/lib/config/chat_service.dart` | Service gọi API chat |
| `backend/src/controllers/chat.controller.js` | Controller xử lý chat |
| `backend/src/routes/chat.routes.js` | Định nghĩa routes |
| `backend/src/config/supabase.js` | Supabase client |

---

## API Endpoints

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| POST | `/api/chat` | Gửi tin nhắn |
| POST | `/api/chat/clear` | Xóa conversation history |

---

## Công Nghệ Sử Dụng

- **Frontend Mobile**: Flutter với Supabase Auth
- **Backend**: Node.js/Express
- **LLM Provider**: **Groq** (Llama 3.3 70B Versatile)
- **Database**: Supabase (PostgreSQL)
- **Auth**: JWT qua Supabase

---

## Database Schema

### Table: `chat_history`

```sql
CREATE TABLE chat_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  conversation_id TEXT,
  role TEXT CHECK (role IN ('user', 'assistant')),
  content TEXT,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Table: `transactions`

```sql
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  category_id UUID REFERENCES categories(id),
  amount DECIMAL(15, 2) NOT NULL,
  type TEXT CHECK (type IN ('income', 'expense')),
  description TEXT,
  transaction_date DATE NOT NULL,
  ocr_data JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```
