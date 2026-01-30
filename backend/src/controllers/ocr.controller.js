const { analyzeReceipt } = require('../services/gemini.service');

// Phân tích từ file upload (Web)
exports.analyzeReceipt = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Không có file ảnh' });
    }

    console.log('Processing receipt image:', req.file.originalname, req.file.mimetype, req.file.size);

    const imageBase64 = req.file.buffer.toString('base64');
    const mimeType = req.file.mimetype;

    const result = await analyzeReceipt(imageBase64, mimeType);
    
    // Log kết quả để debug
    console.log('OCR Result:', JSON.stringify(result, null, 2));

    // Thêm metadata
    result.processedAt = new Date().toISOString();
    result.imageSize = req.file.size;
    
    res.json(result);

  } catch (error) {
    console.error('OCR Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

// Phân tích từ base64 string (cho mobile app)
exports.analyzeReceiptBase64 = async (req, res) => {
  try {
    const { image, mimeType = 'image/jpeg' } = req.body;

    if (!image) {
      return res.status(400).json({ success: false, error: 'Không có dữ liệu ảnh' });
    }

    // Loại bỏ prefix data:image/...;base64, nếu có
    const base64Data = image.replace(/^data:image\/\w+;base64,/, '');
    
    console.log('📸 Processing base64 image, length:', base64Data.length);

    const result = await analyzeReceipt(base64Data, mimeType);
    
    // Log kết quả để debug
    console.log('🔍 OCR Result:', JSON.stringify(result, null, 2));

    // Validate result
    if (!result || typeof result !== 'object') {
      console.error('❌ Invalid result from analyzeReceipt:', result);
      return res.status(500).json({ 
        success: false, 
        error: 'Kết quả phân tích không hợp lệ' 
      });
    }

    // Thêm metadata
    result.processedAt = new Date().toISOString();
    
    res.json(result);

  } catch (error) {
    console.error('❌ OCR Error:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};
