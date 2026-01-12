const { analyzeReceipt } = require('../services/gemini.service');

// Phân tích từ file upload
exports.analyzeReceipt = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Không có file ảnh' });
    }

    const imageBase64 = req.file.buffer.toString('base64');
    const mimeType = req.file.mimetype;

    const result = await analyzeReceipt(imageBase64, mimeType);
    res.json(result);

  } catch (error) {
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

    const result = await analyzeReceipt(base64Data, mimeType);
    res.json(result);

  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};
