const express = require('express');
const router = express.Router();
const multer = require('multer');
const ocrController = require('../controllers/ocr.controller');
const authMiddleware = require('../middleware/auth');

// Cấu hình multer để nhận file ảnh
const storage = multer.memoryStorage();
const upload = multer({ 
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // Max 10MB
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Chỉ chấp nhận file ảnh'), false);
    }
  }
});

router.use(authMiddleware);

// POST /api/ocr/analyze - Phân tích ảnh hóa đơn
router.post('/analyze', upload.single('image'), ocrController.analyzeReceipt);

// POST /api/ocr/analyze-base64 - Phân tích từ base64 (cho mobile)
router.post('/analyze-base64', ocrController.analyzeReceiptBase64);

module.exports = router;
