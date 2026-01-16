const express = require('express');
const router = express.Router();
const goalsController = require('../controllers/goals.controller');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

// CRUD mục tiêu
router.get('/', goalsController.getAll);
router.post('/', goalsController.create);
router.put('/:id', goalsController.update);
router.delete('/:id', goalsController.delete);

// Góp tiền vào mục tiêu
router.post('/:goalId/contribute', goalsController.contribute);

// AI gợi ý mục tiêu
router.get('/ai-suggestions', goalsController.getAISuggestions);

module.exports = router;
