const express = require('express');
const { aiService } = require('../services/aiProvider');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// GET /api/ai/status
router.get('/status', authenticateToken, (req, res) => {
  res.json({
    success: true,
    data: aiService.getStatus()
  });
});

module.exports = router;
