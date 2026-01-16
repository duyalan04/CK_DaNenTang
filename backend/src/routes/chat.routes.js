const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chat.controller');
const authMiddleware = require('../middleware/auth');

// POST /api/chat - Gửi tin nhắn
router.post('/', authMiddleware.optionalAuth, chatController.sendMessage);

// POST /api/chat/clear - Xóa conversation history
router.post('/clear', authMiddleware.optionalAuth, chatController.clearHistory);

module.exports = router;
