const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GOOGLE_AI_API_KEY);

const RECEIPT_PROMPT = `Bạn là chuyên gia OCR phân tích hóa đơn Việt Nam. Phân tích ảnh hóa đơn và trích xuất thông tin chính xác.

## CÁC LOẠI HÓA ĐƠN VIỆT NAM PHỔ BIẾN:

1. **Cửa hàng tiện lợi**: GS25, Circle K, 7-Eleven, Ministop, FamilyMart
2. **Siêu thị**: Co.opmart, Big C, Lotte Mart, AEON, Vinmart, Bach Hoa Xanh
3. **Nhà hàng/Quán ăn**: Có "Hóa đơn thanh toán", "Phiếu thanh toán", "Bill"
4. **Nhà thuốc**: "Phiếu tạm tính", "Hóa đơn bán hàng"
5. **Spa/Dịch vụ**: "Phiếu thanh toán", có danh sách dịch vụ
6. **Cửa hàng điện tử/KiotViet**: Logo KiotViet, có mã HĐ

## CÁCH NHẬN DIỆN SỐ TIỀN TỔNG CỘNG:

Tìm các từ khóa theo thứ tự ưu tiên:
1. "Tổng thanh toán" / "Tổng cộng" / "TỔNG" (ưu tiên cao nhất)
2. "Thành tiền" (cuối cùng trong hóa đơn)
3. "Tổng tiền hàng" / "Cộng tiền hàng"
4. "Total" / "Grand Total"
5. "Tiền khách trả" / "Tiền mặt" (số tiền thực trả)

⚠️ QUAN TRỌNG:
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

CHỈ TRẢ VỀ JSON, KHÔNG CÓ TEXT KHÁC.`;

async function analyzeReceipt(imageBase64, mimeType = 'image/jpeg') {
  try {
    const model = genAI.getGenerativeModel({ 
      model: 'gemini-2.0-flash',
      generationConfig: {
        temperature: 0.1, // Giảm temperature để output chính xác hơn
        topP: 0.8,
        maxOutputTokens: 2048,
      }
    });

    const result = await model.generateContent([
      RECEIPT_PROMPT,
      {
        inlineData: {
          data: imageBase64,
          mimeType: mimeType
        }
      }
    ]);

    const response = result.response.text();
    console.log('Gemini Raw Response:', response);
    
    // Parse JSON từ response
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return { success: false, error: 'Không thể parse kết quả từ AI' };
    }

    const parsed = JSON.parse(jsonMatch[0]);
    
    // Validate và clean data
    if (parsed.totalAmount) {
      // Đảm bảo totalAmount là số
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

module.exports = { analyzeReceipt, cleanAmount };
