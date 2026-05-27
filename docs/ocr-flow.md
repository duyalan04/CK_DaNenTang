# Luồng Xử Lý OCR Nhận Diện Văn Bản

Tài liệu này mô tả chi tiết luồng xử lý OCR (Optical Character Recognition) trong ứng dụng, từ khi người dùng chụp ảnh hóa đơn đến khi lưu giao dịch.

---

## Sơ Đồ Tổng Quan

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MOBILE APP (Flutter)                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────────────┐    │
│  │ Chụp ảnh/   │───▶│ Chọn ảnh     │───▶│ Convert → Base64           │    │
│  │ Chọn ảnh    │    │ từ Camera/   │    │ (Image → Base64 string)    │    │
│  └─────────────┘    │ Gallery       │    └───────────┬─────────────────┘    │
│                    └──────────────┘                  │                      │
└───────────────────────────────────────────────────────│──────────────────────┘
                                                        │
                                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BACKEND (Node.js)                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     OCR Controller                                    │   │
│  │  ┌─────────────────┐    ┌────────────────────────────────────────┐  │   │
│  │  │ analyzeReceipt  │───▶│ Xử lý base64 (loại bỏ prefix)         │  │   │
│  │  │ Base64          │    │ data:image/jpeg;base64,...            │  │   │
│  │  └─────────────────┘    └──────────────────┬─────────────────────┘  │   │
│  └────────────────────────────────────────────│────────────────────────┘   │
│                                               │                             │
└───────────────────────────────────────────────│─────────────────────────────┘
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GEMINI SERVICE (Google AI)                               │
│                                                                             │
│  ┌──────────────┐    ┌─────────────────┐    ┌───────────────────────────┐ │
│  │ Check Cache  │───▶│ Rate Limiter    │───▶│ Gemini 2.5 Flash API      │ │
│  │ (5 phút)     │    │ Queue + Retry   │    │ (AI phân tích ảnh)       │ │
│  └──────────────┘    └─────────────────┘    └───────────┬───────────────┘ │
│                                                          │                 │
│                                                          ▼                 │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                      PROMPT ENGINEERING                                │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │ Bạn là chuyên gia OCR phân tích hóa đơn Việt Nam...            │  │ │
│  │  │                                                                  │  │ │
│  │  │ - Nhận diện GS25, Circle K, Siêu thị, Nhà hàng...              │  │ │
│  │  │ - Tìm "Tổng thanh toán", "Thành tiền"...                      │  │ │
│  │  │ - Trích xuất: storeName, items, totalAmount, date...         │  │ │
│  │  │ - Đề xuất category: Ăn uống, Mua sắm, Sức khỏe...            │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                          │                  │
│                                                          ▼                  │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                    JSON PARSING & CLEANING                              │  │
│  │  - Parse JSON từ response AI                                         │  │
│  │  - Xử lý lỗi: trailing commas, unescaped quotes                      │  │
│  │  - Clean số tiền: "1.344.600đ" → 1344600                            │  │
│  │  - Fallback: nếu JSON bị cắt → gọi summary prompt                   │  │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                                │
                                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        KẾT QUẢ TRẢ VỀ                                     │
│                                                                             │
│  {                                                                       │
│    "success": true,                                                       │
│    "storeName": "GS25 Nguyễn Trãi",                                      │
│    "totalAmount": 14000,                                                  │
│    "date": "2026-05-27",                                                 │
│    "items": [...],                                                        │
│    "suggestedCategory": "Ăn uống",                                       │
│    "confidence": 85                                                      │
│  }                                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Chi Tiết Từng Bước

### Bước 1: Chụp/Chọn Ảnh (Mobile)

**File**: `mobile/lib/screens/ocr_screen.dart`

```dart
// Dòng 43-69
Future<void> _pickImage(ImageSource source) async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1200,
  );

  if (pickedFile != null) {
    final bytes = await pickedFile.readAsBytes();
    // Chuyển đổi sang base64
    // ...
    await _analyzeWithAI();
  }
}
```

**Người dùng có thể**:
- Chụp ảnh trực tiếp từ camera
- Chọn ảnh từ thư viện

---

### Bước 2: Convert Sang Base64

**File**: `mobile/lib/screens/ocr_screen.dart` (dòng 82)

```dart
final base64Image = base64Encode(_imageBytes!);
```

Ảnh được chuyển đổi thành chuỗi Base64 để có thể gửi qua HTTP request.

---

### Bước 3: Gửi Request Lên Backend

**File**: `mobile/lib/config/api.dart` (dòng 152-164)

```dart
Future<Map<String, dynamic>> analyzeReceiptWithAI(String base64Image) async {
  final response = await _dio.post(
    '/ocr/analyze-base64',
    data: {
      'image': base64Image,
      'mimeType': 'image/jpeg',
    },
    options: Options(
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  return response.data;
}
```

---

### Bước 4: Xử Lý Base64 Ở Backend

**File**: `backend/src/controllers/ocr.controller.js` (dòng 42)

```javascript
// Loại bỏ prefix data:image/...;base64, nếu có
const base64Data = image.replace(/^data:image\/\w+;base64,/, '');
```

---

### Bước 5: Gọi Gemini API

**File**: `backend/src/services/gemini.service.js` (dòng 224-279)

```javascript
async function callGeminiWithRetry(imageBase64, mimeType, attempt, prompt, maxOutputTokens) {
  const model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
    generationConfig: {
      temperature: 0.1,
      topP: 0.8,
      maxOutputTokens,
      responseMimeType: 'application/json',
    }
  });

  const result = await model.generateContent([
    prompt,
    {
      inlineData: {
        data: imageBase64,
        mimeType: mimeType
      }
    }
  ]);

  return result.response.text();
}
```

---

### Bước 6: Prompt Engineering

**File**: `backend/src/services/gemini.service.js` (dòng 20-105)

Prompt yêu cầu AI trả về JSON với cấu trúc cụ thể:

```javascript
const RECEIPT_PROMPT = `Bạn là chuyên gia OCR phân tích hóa đơn Việt Nam...

## CÁC LOẠI HÓA ĐƠN VIỆT NAM PHỔ BIẾN:
1. Cửa hàng tiện lợi: GS25, Circle K, 7-Eleven, Ministop, FamilyMart
2. Siêu thị: Co.opmart, Big C, Lotte Mart, AEON, Vinmart, Bach Hoa Xanh
3. Nhà hàng/Quán ăn: Có "Hóa đơn thanh toán", "Phiếu thanh toán", "Bill"
...

## OUTPUT FORMAT (JSON):
{
  "success": true,
  "storeName": "Tên cửa hàng",
  "totalAmount": 14000,
  "items": [...],
  "suggestedCategory": "Ăn uống",
  ...
}
`;
```

**Các loại hóa đơn được hỗ trợ**:
- Cửa hàng tiện lợi (GS25, Circle K, 7-Eleven...)
- Siêu thị (Co.opmart, Big C, Lotte Mart...)
- Nhà hàng/Quán ăn
- Nhà thuốc
- Spa/Dịch vụ
- Cửa hàng điện tử (KiotViet)
- Hóa đơn điện tử trên web/app

---

### Bước 7: Xử Lý JSON Response

**File**: `backend/src/services/gemini.service.js` (dòng 329-434)

```javascript
// 1. Remove markdown code blocks nếu có
jsonStr = jsonStr.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/\s*```$/,'');

// 2. Tìm JSON object trong response
const jsonMatch = jsonStr.match(/\{[\s\S]*\}/);

// 3. Remove trailing commas before } or ]
jsonStr = jsonStr.replace(/,(\s*[}\]])/g, '$1');

// 4. Fix unescaped quotes trong strings
jsonStr = jsonStr.replace(/"([^"]*?)"/g, (match, content) => {
  const escaped = content.replace(/(?<!\\)"/g, '\\"');
  return `"${escaped}"`;
});

// 5. Remove control characters
jsonStr = jsonStr.replace(/[\x00-\x1F\x7F]/g, ' ');

// 6. Fix số có dấu phẩy trong JSON (14,000 -> 14000)
jsonStr = jsonStr.replace(/:\s*(\d{1,3}(?:,\d{3})+)(?=[,}\]\s])/g, ...);

parsed = JSON.parse(jsonStr);
```

---

### Bước 8: Clean Số Tiền

**File**: `backend/src/services/gemini.service.js` (dòng 492-539)

```javascript
function cleanAmount(value) {
  if (typeof value === 'number') return value;
  if (!value) return 0;

  let str = String(value);

  // Remove currency symbols và text
  str = str.replace(/[đdĐD₫VND\s]/gi, '');

  // Xử lý format số Việt Nam
  // "1.344.600đ" → 1344600
  // "14,000" → 14000

  return Math.round(parseFloat(str));
}
```

**Ví dụ**:
| Input | Output |
|-------|--------|
| `"1,344,600đ"` | `1344600` |
| `"14,000"` | `14000` |
| `"300,000"` | `300000` |

---

### Bước 9: Nhận Kết Quả Ở Mobile

**File**: `mobile/lib/screens/ocr_screen.dart` (dòng 86-112)

```dart
final result = await apiService.analyzeReceiptWithAI(base64Image);

if (result['success'] != true) {
  throw Exception(result['error'] ?? 'OCR failed');
}

setState(() {
  _aiResult = result;
  _isProcessing = false;

  // Auto-select category
  if (result['suggestedCategory'] != null) {
    _autoSelectCategory(result['suggestedCategory']);
  }

  // Auto-select date
  if (result['date'] != null) {
    _selectedDate = DateTime.parse(result['date']);
  }
});
```

---

### Bước 10: Lưu Giao Dịch

**File**: `mobile/lib/screens/ocr_screen.dart` (dòng 172-215)

```dart
await apiService.createFromOCR({
  'ocrData': {
    'rawText': _aiResult!['storeName'] ?? '',
    'extractedAmount': _aiResult!['totalAmount'],
    'extractedItems': (_aiResult!['items'] as List?)?.map((i) => i['name']).toList() ?? [],
    'receiptItems': (_aiResult!['items'] as List?) ?? [],
    'storeName': _aiResult!['storeName'],
    'invoiceNumber': _aiResult!['invoiceNumber'],
    'receiptDate': _aiResult!['date'],
    'totalAmount': _aiResult!['totalAmount'],
    'suggestedCategory': _aiResult!['suggestedCategory'],
    'aiAnalysis': _aiResult,
  },
  'categoryId': validCatId,
  'transactionDate': _selectedDate.toIso8601String().split('T')[0],
});
```

---

## Cơ Chế Xử Lý Đặc Biệt

### 1. Rate Limiting & Queue

**File**: `backend/src/services/gemini.service.js` (dòng 5-11)

```javascript
const RATE_LIMIT_CONFIG = {
  maxRetries: 3,
  baseDelayMs: 1000,
  maxDelayMs: 30000,
  maxConcurrent: 2,
  requestsPerMinute: 10,
};
```

- **Queue**: Request được đưa vào hàng đợi nếu đang có quá nhiều request
- **Retry**: Tự động thử lại với exponential backoff khi bị rate limit
- **Concurrent limit**: Tối đa 2 request chạy song song

### 2. Caching

**File**: `backend/src/services/gemini.service.js` (dòng 17-18)

```javascript
const responseCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 phút
```

- Kết quả OCR được cache 5 phút
- Tránh gọi API trùng lặp cho cùng một ảnh

### 3. Fallback Strategy

**File**: `backend/src/services/gemini.service.js` (dòng 373-404)

Khi JSON bị cắt do hóa đơn quá dài:

1. Trích xuất các items đã parse được
2. Gọi **RECEIPT_SUMMARY_PROMPT** - prompt ngắn hơn chỉ lấy thông tin tổng quan
3. Kết hợp kết quả summary với items đã trích xuất

---

## Cấu Trúc Dữ Liệu

### Request

```json
{
  "image": "base64_encoded_image_string",
  "mimeType": "image/jpeg"
}
```

### Response Thành Công

```json
{
  "success": true,
  "storeName": "GS25 Nguyễn Trãi",
  "storeAddress": "123 Nguyễn Trãi, Q1, HCM",
  "storePhone": "02812345678",
  "invoiceNumber": "HD001234",
  "date": "2026-05-27",
  "time": "14:30",
  "items": [
    {
      "name": "Cà phê sữa",
      "quantity": 2,
      "unitPrice": 25000,
      "total": 50000
    }
  ],
  "subtotal": 55000,
  "discountAmount": 5000,
  "totalAmount": 50000,
  "paymentMethod": "Tiền mặt",
  "suggestedCategory": "Ăn uống",
  "confidence": 85,
  "rawText": "GS25 Nguyễn Trãi..."
}
```

### Response Lỗi

```json
{
  "success": false,
  "error": "Không thể đọc thông tin từ hóa đơn. Vui lòng chụp rõ hơn."
}
```

---

## Các File Liên Quan

| File | Mô tả |
|------|-------|
| `mobile/lib/screens/ocr_screen.dart` | Giao diện quét hóa đơn (Flutter) |
| `mobile/lib/config/api.dart` | API service gọi backend |
| `backend/src/controllers/ocr.controller.js` | Controller xử lý OCR request |
| `backend/src/services/gemini.service.js` | Service gọi Gemini API |
| `backend/src/routes/ocr.routes.js` | Định nghĩa routes OCR |
| `backend/src/controllers/transaction.controller.js` | Lưu giao dịch từ OCR |

---

## API Endpoints

| Method | Endpoint | Mô tả |
|--------|----------|-------|
| POST | `/api/ocr/analyze` | Upload file ảnh (Web) |
| POST | `/api/ocr/analyze-base64` | Gửi ảnh dạng base64 (Mobile) |
| POST | `/api/transactions/ocr` | Tạo giao dịch từ dữ liệu OCR |

---

## Công Nghệ Sử Dụng

- **Frontend Mobile**: Flutter với `image_picker`
- **Backend**: Node.js/Express
- **AI Engine**: **Google Gemini 2.5 Flash**
- **Rate Limiting**: Custom queue system
- **Caching**: In-memory Map với TTL
