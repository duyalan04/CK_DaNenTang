const express = require('express');
const router = express.Router();
const budgetController = require('../controllers/budget.controller');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.get('/', budgetController.getAll);
router.get('/month/:year/:month', budgetController.getByMonth);
router.post('/', budgetController.create);
router.put('/:id', budgetController.update);
router.delete('/:id', budgetController.delete);

module.exports = router;
