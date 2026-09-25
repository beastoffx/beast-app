const jwt = require('jsonwebtoken');
const config = require('../config');
const { get } = require('../db');

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'Access denied. No authentication token provided.'
    });
  }

  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    // Fetch live user status to ensure account is not deactivated
    const user = get('SELECT id, email, role, name, phone, is_active FROM users WHERE id = ?', [decoded.id]);

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid session. User no longer exists.'
      });
    }

    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        error: 'Account has been deactivated. Please contact administration.'
      });
    }

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Session has expired. Please log in again.'
      });
    }
    return res.status(401).json({
      success: false,
      error: 'Invalid authentication token.'
    });
  }
}

module.exports = { authenticateToken };
