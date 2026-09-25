const express = require('express');
const { query, run } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// GET /api/notifications/my
router.get('/my', authenticateToken, (req, res) => {
  const notifications = query(
    'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 25',
    [req.user.id]
  );
  const unreadCount = notifications.filter(n => !n.is_read).length;

  res.json({
    success: true,
    data: {
      notifications,
      unreadCount
    }
  });
});

// PUT /api/notifications/:id/read
router.put('/:id/read', authenticateToken, (req, res) => {
  run('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
  res.json({ success: true, message: 'Notification marked as read.' });
});

// PUT /api/notifications/read-all
router.put('/read-all', authenticateToken, (req, res) => {
  run('UPDATE notifications SET is_read = 1 WHERE user_id = ?', [req.user.id]);
  res.json({ success: true, message: 'All notifications marked as read.' });
});

module.exports = router;
