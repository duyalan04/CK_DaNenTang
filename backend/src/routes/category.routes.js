const express = require('express');
const router = express.Router();
const categoryController = require('../controllers/category.controller');
const authMiddleware = require('../middleware/auth');

router.use(authMiddleware);

router.get('/', categoryController.getAll);
router.post('/', categoryController.create);
router.post('/init-defaults', categoryController.initDefaults);
router.put('/:id', categoryController.update);
router.delete('/:id', categoryController.delete);

module.exports = router;
