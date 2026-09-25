function errorHandler(err, req, res, next) {
  console.error('[SERVER_ERROR]', err.message);

  if (err.name === 'MulterError') {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        error: 'File size exceeds maximum permitted limit (25 MB).'
      });
    }
    return res.status(400).json({
      success: false,
      error: `File upload error: ${err.message}`
    });
  }

  if (err.message && err.message.includes('Invalid file type')) {
    return res.status(400).json({
      success: false,
      error: err.message
    });
  }

  res.status(500).json({
    success: false,
    error: 'An internal server error occurred while processing your academic request. Please try again.'
  });
}

function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    error: `Resource not found: ${req.method} ${req.originalUrl}`
  });
}

module.exports = { errorHandler, notFoundHandler };
