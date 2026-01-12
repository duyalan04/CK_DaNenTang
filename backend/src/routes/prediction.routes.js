const express = require('express');
const router = express.Router();
const predictionController = require('../controllers/prediction.controller');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.get('/next-month', predictionController.predictNextMonth);
router.get('/by-category', predictionController.predictByCategory);

module.exports = router;
