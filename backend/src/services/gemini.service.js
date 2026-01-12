const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GOOGLE_AI_API_KEY);

const RECEIPT_PROMPT = `Bạn là chuyên gia phân tích hóa đơn. Hãy phân tích ảnh hóa đơn này và trả về JSON với format sau:
{
  "success": true/false,
  "storeName": "Tên cửa hàng/siêu thị",
  "storeAddress": "Địa chỉ (nếu có)",
  "date": "Ngày trên hóa đơn (YYYY-MM-DD)",
  "totalAmount": số tiền tổng cộng (chỉ số, không có đơn vị),
  "currency": "VND/USD/...",
  "items": [
    {"name": "Tên sản phẩm", "quantity": số lượng, "price": đơn giá, "total": thành tiền}
  ],
  "paymentMethod": "Tiền mặt/Thẻ/...",
  "taxAmount": số tiền thuế (nếu có),
  "discountAmount": số tiền giảm giá (nếu có),
  "suggestedCategory": "Ăn uống/Mua sắm/Di chuyển/Hóa đơn/Sức khỏe/Giải trí",
  "confidence": độ tin cậy từ 0-100
}

Lưu ý:
- Nếu không đọc được, trả về {"success": false, "error": "Lý do"}
- totalAmount phải là số, không có dấu phẩy hay đơn vị tiền
- Ưu tiên lấy số tiền "Tổng cộng", "Total", "Thành tiền" cuối cùng
- suggestedCategory dựa vào loại cửa hàng/sản phẩm
- Chỉ trả về JSON, không có text khác`;

async function analyzeReceipt(imageBase64, mimeType = 'image/jpeg') {
  try {
    const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

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
    
    // Parse JSON từ response
    const jsonMatch = response.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return { success: false, error: 'Không thể parse kết quả' };
    }

    const parsed = JSON.parse(jsonMatch[0]);
    return parsed;

  } catch (error) {
    console.error('Gemini API Error:', error);
    return { 
      success: false, 
      error: error.message || 'Lỗi khi phân tích hóa đơn' 
    };
  }
}

module.exports = { analyzeReceipt };
