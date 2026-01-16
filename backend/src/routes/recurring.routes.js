const express = require('express');
const router = express.Router();
const recurringController = require('../controllers/recurring.controller');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

// CRUD giao dịch định kỳ
router.get('/', recurringController.getAll);
router.post('/', recurringController.create);
router.put('/:id', recurringController.update);
router.delete('/:id', recurringController.delete);

// Dự báo chi tiêu định kỳ
router.get('/forecast', recurringController.getForecast);

// Process recurring (cho cron job - cần thêm API key check)
router.post('/process', recurringController.processRecurring);

module.exports = router;
