const express = require('express');
const router = express.Router();
const analyticsController = require('../controllers/analytics.controller');
const authMiddleware = require('../middleware/auth');

// Tất cả routes yêu cầu authentication
router.use(authMiddleware);

/**
 * @route   GET /api/analytics/anomalies
 * @desc    Phát hiện giao dịch bất thường bằng Z-score
 * @access  Private
 */
router.get('/anomalies', analyticsController.detectAnomalies);

/**
 * @route   GET /api/analytics/health-score
 * @desc    Tính điểm sức khỏe tài chính (0-100)
 * @access  Private
 */
router.get('/health-score', analyticsController.calculateHealthScore);

/**
 * @route   GET /api/analytics/insights
 * @desc    Tạo AI insights từ dữ liệu tài chính
 * @access  Private
 */
router.get('/insights', analyticsController.generateInsights);

/**
 * @route   GET /api/analytics/savings
 * @desc    Gợi ý tiết kiệm dựa trên phân tích chi tiêu
 * @access  Private
 */
router.get('/savings', analyticsController.calculateSavings);

module.exports = router;
