const express = require('express');
const router = express.Router();
const smartController = require('../controllers/smart.controller');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

/**
 * @route   GET /api/smart/analysis
 * @desc    Phân tích chi tiêu thông minh với AI
 * @query   period: 'week' | 'month' | 'quarter'
 */
router.get('/analysis', smartController.getSmartAnalysis);

/**
 * @route   GET /api/smart/patterns
 * @desc    Phát hiện mẫu chi tiêu (ngày, tuần, category)
 */
router.get('/patterns', smartController.getSpendingPatterns);

/**
 * @route   GET /api/smart/budget-suggestions
 * @desc    Gợi ý ngân sách thông minh theo quy tắc 50/30/20
 */
router.get('/budget-suggestions', smartController.getSmartBudgetSuggestions);

/**
 * @route   GET /api/smart/forecast
 * @desc    Dự báo tài chính tương lai
 * @query   months: số tháng dự báo (default: 3)
 */
router.get('/forecast', smartController.getFinancialForecast);

module.exports = router;
