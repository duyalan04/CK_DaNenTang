const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GOOGLE_AI_API_KEY);

const RATE_LIMIT_CONFIG = {
  maxRetries: 3,
  baseDelayMs: 1000,    
  maxDelayMs: 30000,    
  maxConcurrent: 2,     
  requestsPerMinute: 10, 
};

let activeRequests = 0;
let requestQueue = [];
let requestTimestamps = [];

const responseCache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000;

const RECEIPT_PROMPT = `Bạn là chuyên gia OCR phân tích hóa đơn Việt Nam, bao gồm hóa đơn giấy và hóa đơn điện tử/website như GS25. Phân tích ảnh hóa đơn và trích xuất thông tin chính xác.

QUAN TRỌNG: CHỈ TRẢ VỀ JSON HỢP LỆ, KHÔNG CÓ MARKDOWN, KHÔNG CÓ TEXT GIẢI THÍCH TRƯỚC HOẶC SAU JSON. JSON phải ngắn gọn để tránh bị cắt.

## CÁC LOẠI HÓA ĐƠN VIỆT NAM PHỔ BIẾN:

1. **Cửa hàng tiện lợi**: GS25, Circle K, 7-Eleven, Ministop, FamilyMart
2. **Siêu thị**: Co.opmart, Big C, Lotte Mart, AEON, Vinmart, Bach Hoa Xanh
3. **Nhà hàng/Quán ăn**: Có "Hóa đơn thanh toán", "Phiếu thanh toán", "Bill"
4. **Nhà thuốc**: "Phiếu tạm tính", "Hóa đơn bán hàng"
5. **Spa/Dịch vụ**: "Phiếu thanh toán", có danh sách dịch vụ
6. **Cửa hàng điện tử/KiotViet**: Logo KiotViet, có mã HĐ
7. **Hóa đơn điện tử trên web/app**: Có domain, bảng sản phẩm, "Mã hóa đơn", "Thời gian", "Thành tiền"

## CÁCH NHẬN DIỆN SỐ TIỀN TỔNG CỘNG:

Tìm các từ khóa theo thứ tự ưu tiên:
1. "Tổng thanh toán" / "Tổng cộng" / "TỔNG" (ưu tiên cao nhất)
2. "Thành tiền" (cuối cùng trong hóa đơn)
3. "Tổng tiền hàng" / "Cộng tiền hàng"
4. "Total" / "Grand Total"
5. "Tiền khách trả" / "Tiền mặt" (số tiền thực trả)

QUAN TRỌNG:
- Lấy số tiền CUỐI CÙNG, SAU khi đã trừ giảm giá/khuyến mãi
- Nếu có "Tiền trả lại khách" thì tổng = "Tiền khách trả" - "Tiền trả lại"
- Số tiền VND thường có dấu chấm hoặc dấu phẩy ngăn cách hàng nghìn (14,000 hoặc 14.000 = 14000)
- Bỏ qua các ký tự: đ, VND, VNĐ, d

## ĐỊNH DẠNG SỐ TIỀN VIỆT NAM:
- "14,000" hoặc "14.000" = 14000
- "1,344,600đ" hoặc "1.344.600d" = 1344600
- "6,840,000" = 6840000
- "110,000" = 110000
- "300,000" = 300000

## OUTPUT FORMAT (JSON):

{
  "success": true,
  "storeName": "Tên cửa hàng (đọc từ logo hoặc header)",
  "storeAddress": "Địa chỉ nếu có",
  "storePhone": "Số điện thoại nếu có",
  "invoiceNumber": "Số hóa đơn/Số HĐ nếu có",
  "date": "YYYY-MM-DD (chuyển đổi từ DD/MM/YYYY)",
  "time": "HH:MM nếu có",
  "items": [
    {
      "name": "Tên sản phẩm/dịch vụ",
      "quantity": 1,
      "unitPrice": 14000,
      "total": 14000
    }
  ],
  "subtotal": "Tổng tiền hàng trước giảm giá (số)",
  "discountAmount": "Số tiền giảm giá (số, 0 nếu không có)",
  "discountPercent": "Phần trăm giảm nếu có",
  "taxAmount": "Tiền thuế VAT nếu có (số)",
  "taxPercent": "% VAT nếu có",
  "totalAmount": "SỐ TIỀN CUỐI CÙNG PHẢI TRẢ (số nguyên, không có dấu)",
  "amountPaid": "Tiền khách đưa nếu có",
  "changeAmount": "Tiền trả lại nếu có",
  "paymentMethod": "Tiền mặt/Thẻ/Chuyển khoản",
  "currency": "VND",
  "cashier": "Tên thu ngân/nhân viên nếu có",
  "suggestedCategory": "Một trong: Ăn uống, Mua sắm, Sức khỏe, Giải trí, Di chuyển, Hóa đơn, Khác",
  "confidence": 85,
  "rawText": "Các dòng text quan trọng đọc được"
}

## QUY TẮC PHÂN LOẠI (suggestedCategory):

- **Ăn uống**: Nhà hàng, quán ăn, cafe, trà sữa, cửa hàng tiện lợi (nếu mua đồ ăn)
- **Mua sắm**: Siêu thị, cửa hàng điện tử, quần áo, đồ gia dụng
- **Sức khỏe**: Nhà thuốc, phòng khám, spa, massage, gym
- **Giải trí**: Rạp phim, karaoke, game, du lịch
- **Di chuyển**: Xăng dầu, taxi, grab, gửi xe
- **Hóa đơn**: Điện, nước, internet, điện thoại

## VÍ DỤ PHÂN TÍCH:

Hóa đơn GS25 với "Tổng tiền: 14,000" → totalAmount: 14000
Hóa đơn nhà hàng với "Tổng thanh toán: 1.344.600đ" → totalAmount: 1344600
Hóa đơn spa với "Thành tiền: 300,000" → totalAmount: 300000

BẮT BUỘC: Response phải bắt đầu bằng { và kết thúc bằng }. Không thêm text giải thích.`;

const RECEIPT_SUMMARY_PROMPT = `Bạn là chuyên gia OCR hóa đơn Việt Nam. Ảnh có thể là hóa đơn giấy hoặc hóa đơn điện tử/website như GS25.

CHỈ TRẢ VỀ JSON HỢP LỆ, KHÔNG MARKDOWN, KHÔNG GIẢI THÍCH.
Không trả danh sách items. Chỉ đọc thông tin tổng quan:

{
  "success": true,
  "storeName": "Tên cửa hàng",
  "invoiceNumber": "Mã hóa đơn nếu có",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "subtotal": 0,
  "discountAmount": 0,
  "totalAmount": 0,
  "paymentMethod": "Tiền mặt/Thẻ/Chuyển khoản/null",
  "currency": "VND",
  "cashier": "Tên nhân viên nếu có",
  "suggestedCategory": "Ăn uống hoặc Mua sắm hoặc Sức khỏe hoặc Giải trí hoặc Di chuyển hoặc Hóa đơn hoặc Khác",
  "confidence": 80,
  "rawText": "Tối đa 200 ký tự quan trọng"
}

Ưu tiên đọc "Thành tiền", "Tổng", "Tổng cộng", "Tổng thanh toán". Với GS25, "Thành tiền" màu đỏ là totalAmount.`;

function createImageHash(imageBase64) {
  let hash = 0;
  const sample = imageBase64.substring(0, 1000) + imageBase64.substring(imageBase64.length - 1000);
  for (let i = 0; i < sample.length; i++) {
    const char = sample.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash;
  }
  return `img_${hash}_${imageBase64.length}`;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function calculateBackoffDelay(attempt) {
  const delay = Math.min(
    RATE_LIMIT_CONFIG.baseDelayMs * Math.pow(2, attempt),
    RATE_LIMIT_CONFIG.maxDelayMs
  );
  return delay + Math.random() * 1000;
}

function checkRateLimit() {
  const now = Date.now();
  const oneMinuteAgo = now - 60000;
  
  requestTimestamps = requestTimestamps.filter(ts => ts > oneMinuteAgo);
  
  return requestTimestamps.length < RATE_LIMIT_CONFIG.requestsPerMinute;
}

async function enqueueRequest(requestFn) {
  return new Promise((resolve, reject) => {
    requestQueue.push({ requestFn, resolve, reject });
    processQueue();
  });
}

/**
 * Xử lý request queue
 */
async function processQueue() {
  if (requestQueue.length === 0) return;
  if (activeRequests >= RATE_LIMIT_CONFIG.maxConcurrent) return;
  
  // Kiểm tra rate limit
  if (!checkRateLimit()) {
    // Đợi và thử lại
    setTimeout(processQueue, 2000);
    return;
  }
  
  const { requestFn, resolve, reject } = requestQueue.shift();
  activeRequests++;
  requestTimestamps.push(Date.now());
  
  try {
    const result = await requestFn();
    resolve(result);
  } catch (error) {
    reject(error);
  } finally {
    activeRequests--;
    if (requestQueue.length > 0) {
      setTimeout(processQueue, 100);
    }
  }
}

async function callGeminiWithRetry(
  imageBase64,
  mimeType,
  attempt = 0,
  prompt = RECEIPT_PROMPT,
  maxOutputTokens = 4096
) {
  try {
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

  } catch (error) {
    const isRateLimitError = error.status === 429 || 
                             error.message?.includes('429') ||
                             error.message?.includes('quota') ||
                             error.message?.includes('Too Many Requests');
    
    const isRetryableError = isRateLimitError || 
                             error.status === 503 || 
                             error.status === 500;

    if (isRetryableError && attempt < RATE_LIMIT_CONFIG.maxRetries) {
      const delay = calculateBackoffDelay(attempt);
      console.log(`⏳ Rate limit hit, retrying in ${Math.round(delay/1000)}s (attempt ${attempt + 1}/${RATE_LIMIT_CONFIG.maxRetries})`);
      
      await sleep(delay);
      return callGeminiWithRetry(imageBase64, mimeType, attempt + 1, prompt, maxOutputTokens);
    }

    // Nếu vẫn bị rate limit sau khi retry, trả về lỗi thân thiện
    if (isRateLimitError) {
      throw new Error('API đang quá tải. Vui lòng thử lại sau 1-2 phút.');
    }

    throw error;
  }
}

function extractItemsFromResponse(response) {
  const items = [];

  try {
    const itemsMatch = response.match(/"items"\s*:\s*\[([\s\S]*)/i);
    if (!itemsMatch) return items;

    const itemsStr = itemsMatch[1];
    const itemRegex = /\{[^}]*"name"\s*:\s*"([^"]+)"[^}]*"quantity"\s*:\s*([\d.]+)[^}]*"unitPrice"\s*:\s*"?(\d[\d,.\s]*)"?[^}]*"total"\s*:\s*"?(\d[\d,.\s]*)"?[^}]*\}/gi;
    let itemMatch;

    while ((itemMatch = itemRegex.exec(itemsStr)) !== null) {
      items.push({
        name: itemMatch[1],
        quantity: parseFloat(itemMatch[2]) || 1,
        unitPrice: cleanAmount(itemMatch[3]),
        total: cleanAmount(itemMatch[4])
      });
    }
  } catch (itemError) {
    console.error('Failed to extract partial items:', itemError.message);
  }

  return items;
}

// ============ MAIN FUNCTION ============

async function analyzeReceipt(imageBase64, mimeType = 'image/jpeg') {
  try {
    // 1. Kiểm tra cache trước
    const cacheKey = createImageHash(imageBase64);
    const cached = responseCache.get(cacheKey);
    
    if (cached && (Date.now() - cached.timestamp < CACHE_TTL_MS)) {
      console.log('📦 Cache hit - returning cached result');
      return cached.data;
    }

    // 2. Enqueue request với rate limiting
    const response = await enqueueRequest(() => 
      callGeminiWithRetry(imageBase64, mimeType)
    );

    console.log('Gemini Raw Response:', response);
    
    // 3. Parse JSON từ response - với xử lý lỗi tốt hơn
    let parsed;
    try {
      let jsonStr = response.trim();
      
      // Remove markdown code blocks nếu có
      jsonStr = jsonStr.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/\s*```$/,'');
      
      // Tìm JSON object trong response
      const jsonMatch = jsonStr.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        console.error('No JSON found in response:', response.substring(0, 500));
        return { success: false, error: 'Không thể tìm thấy JSON trong response', rawResponse: response.substring(0, 500) };
      }
      
      jsonStr = jsonMatch[0];
      
      // Clean up common JSON issues từ AI
      // 1. Remove trailing commas before } or ]
      jsonStr = jsonStr.replace(/,(\s*[}\]])/g, '$1');
      
      // 2. Fix unescaped quotes trong strings
      // Tìm và escape quotes trong giá trị string
      jsonStr = jsonStr.replace(/"([^"]*?)"/g, (match, content) => {
        // Escape các quote chưa được escape trong content
        const escaped = content.replace(/(?<!\\)"/g, '\\"');
        return `"${escaped}"`;
      });
      
      // 3. Remove control characters
      jsonStr = jsonStr.replace(/[\x00-\x1F\x7F]/g, ' ');
      
      // 4. Fix số có dấu phẩy trong JSON (14,000 -> 14000)
      // Chỉ fix trong context của số, không phải trong string
      jsonStr = jsonStr.replace(/:\s*(\d{1,3}(?:,\d{3})+)(?=[,}\]\s])/g, (match, num) => {
        return ': ' + num.replace(/,/g, '');
      });
      
      parsed = JSON.parse(jsonStr);
      console.log('✅ Successfully parsed JSON');
      
    } catch (parseError) {
      console.error('❌ JSON Parse Error:', parseError.message);
      console.error('Raw response sample:', response.substring(0, 500));
      console.error('Attempting fallback parsing...');

      const partialItems = extractItemsFromResponse(response);

      // Nếu JSON chi tiết bị cắt do bảng sản phẩm dài, gọi lại một prompt cực ngắn
      // chỉ lấy thông tin tổng quan. Trường hợp hóa đơn điện tử GS25 thường rơi vào nhánh này.
      try {
        const summaryResponse = await callGeminiWithRetry(
          imageBase64,
          mimeType,
          0,
          RECEIPT_SUMMARY_PROMPT,
          1024
        );
        console.log('Gemini Summary Fallback Response:', summaryResponse);

        let summaryJson = summaryResponse
          .trim()
          .replace(/^```json\s*/i, '')
          .replace(/^```\s*/, '')
          .replace(/\s*```$/, '');

        const summaryMatch = summaryJson.match(/\{[\s\S]*\}/);
        if (summaryMatch) {
          summaryJson = summaryMatch[0].replace(/,(\s*[}\]])/g, '$1');
          parsed = JSON.parse(summaryJson);
          parsed.items = partialItems;
          parsed.note = partialItems.length > 0
            ? 'Summary parsed after detailed JSON was truncated'
            : 'Summary parsed after detailed JSON was truncated; items omitted';
        }
      } catch (summaryError) {
        console.error('❌ Summary fallback failed:', summaryError.message);
      }
      
      // Fallback: Trích xuất thông tin bằng regex - bao gồm cả items
      if (!parsed) {
        const totalMatch = response.match(/"totalAmount"\s*:\s*"?(\d[\d,.\s]*)"?/i);
        const storeMatch = response.match(/"storeName"\s*:\s*"([^"]+)"/i);
        const dateMatch = response.match(/"date"\s*:\s*"([^"]+)"/i);
        const categoryMatch = response.match(/"suggestedCategory"\s*:\s*"([^"]+)"/i);
        const invoiceMatch = response.match(/"invoiceNumber"\s*:\s*"([^"]+)"/i);
        const timeMatch = response.match(/"time"\s*:\s*"([^"]+)"/i);

        if (totalMatch) {
        parsed = {
          success: true,
          storeName: storeMatch ? storeMatch[1] : 'Không xác định',
          invoiceNumber: invoiceMatch ? invoiceMatch[1] : null,
          date: dateMatch ? dateMatch[1] : new Date().toISOString().split('T')[0],
          time: timeMatch ? timeMatch[1] : null,
          totalAmount: cleanAmount(totalMatch[1]),
          suggestedCategory: categoryMatch ? categoryMatch[1] : 'Mua sắm',
            items: partialItems,
            confidence: partialItems.length > 0 ? 75 : 60,
          note: 'Parsed with fallback method'
        };
        } else {
        return { 
          success: false, 
            error: 'Không thể đọc thông tin từ hóa đơn. Vui lòng chụp rõ hơn hoặc crop rõ vùng tổng tiền.' 
        };
        }
      }
    }
    
    // 4. Validate và clean data
    if (parsed.totalAmount) {
      parsed.totalAmount = cleanAmount(parsed.totalAmount);
    }
    
    if (parsed.subtotal) {
      parsed.subtotal = cleanAmount(parsed.subtotal);
    }
    
    if (parsed.discountAmount) {
      parsed.discountAmount = cleanAmount(parsed.discountAmount);
    }
    
    if (parsed.taxAmount) {
      parsed.taxAmount = cleanAmount(parsed.taxAmount);
    }

    // Clean items
    if (parsed.items && Array.isArray(parsed.items)) {
      parsed.items = parsed.items.map(item => ({
        ...item,
        unitPrice: cleanAmount(item.unitPrice || item.price),
        total: cleanAmount(item.total),
        quantity: parseInt(item.quantity) || 1
      }));
    }

    // 5. Lưu vào cache
    responseCache.set(cacheKey, {
      data: parsed,
      timestamp: Date.now()
    });

    // Cleanup cache cũ (giữ tối đa 100 entries)
    if (responseCache.size > 100) {
      const oldestKey = responseCache.keys().next().value;
      responseCache.delete(oldestKey);
    }

    return parsed;

  } catch (error) {
    console.error('Gemini API Error:', error);
    return { 
      success: false, 
      error: error.message || 'Lỗi khi phân tích hóa đơn' 
    };
  }
}

/**
 * Clean và convert số tiền về number
 * "14,000" → 14000
 * "1.344.600đ" → 1344600
 */
function cleanAmount(value) {
  if (typeof value === 'number') return value;
  if (!value) return 0;
  
  // Convert to string
  let str = String(value);
  
  // Remove currency symbols và text
  str = str.replace(/[đdĐD₫VND\s]/gi, '');
  
  // Xử lý format số Việt Nam
  // Nếu có cả dấu chấm và dấu phẩy, xác định đâu là separator
  if (str.includes('.') && str.includes(',')) {
    // "1.344.600" hoặc "1,344,600"
    // Đếm số lần xuất hiện
    const dots = (str.match(/\./g) || []).length;
    const commas = (str.match(/,/g) || []).length;
    
    if (dots > commas) {
      // Dấu chấm là thousand separator
      str = str.replace(/\./g, '').replace(',', '.');
    } else {
      // Dấu phẩy là thousand separator
      str = str.replace(/,/g, '');
    }
  } else if (str.includes('.')) {
    // Chỉ có dấu chấm - kiểm tra vị trí
    const parts = str.split('.');
    if (parts.length > 2 || (parts[1] && parts[1].length === 3)) {
      // "1.344.600" - thousand separator
      str = str.replace(/\./g, '');
    }
    // Nếu không thì giữ nguyên (decimal)
  } else if (str.includes(',')) {
    // Chỉ có dấu phẩy
    const parts = str.split(',');
    if (parts.length > 2 || (parts[1] && parts[1].length === 3)) {
      // "1,344,600" - thousand separator
      str = str.replace(/,/g, '');
    } else {
      // "14,50" - decimal separator
      str = str.replace(',', '.');
    }
  }
  
  const num = parseFloat(str);
  return isNaN(num) ? 0 : Math.round(num);
}

module.exports = { 
  analyzeReceipt, 
  cleanAmount,
  // Export để có thể điều chỉnh config nếu cần
  getRateLimitStatus: () => ({
    activeRequests,
    queueLength: requestQueue.length,
    requestsLastMinute: requestTimestamps.filter(ts => ts > Date.now() - 60000).length,
    cacheSize: responseCache.size
  })
};
