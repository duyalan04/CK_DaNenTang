const express = require('express');
const router = express.Router();
const transactionController = require('../controllers/transaction.controller');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.get('/', transactionController.getAll);
router.get('/:id', transactionController.getById);
router.post('/', transactionController.create);
router.put('/:id', transactionController.update);
router.delete('/:id', transactionController.delete);
router.post('/ocr', transactionController.createFromOCR);
router.post('/parse-voice', transactionController.parseVoice);
router.post('/parse-sms', transactionController.parseSms);

module.exports = router;
