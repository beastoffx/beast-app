// Vercel Serverless Function: Edge API Proxy for B.E.A.S.T ACADEMY
// Eliminates browser cross-origin CORS preflight failures by proxying requests
// server-to-server to the authoritative Render production backend.

module.exports = async (req, res) => {
  // Construct the target URL on the Render production API
  const cleanUrl = req.url.startsWith('/api') ? req.url : `/api${req.url}`;
  const targetUrl = `https://beast-academy-api.onrender.com${cleanUrl}`;

  // Forward headers but omit origin, host, and referer so the backend
  // treats it as an authoritative client without CORS rejection
  const headers = {};
  for (const [key, value] of Object.entries(req.headers)) {
    const lowerKey = key.toLowerCase();
    if (!['host', 'origin', 'referer', 'connection', 'content-length'].includes(lowerKey)) {
      headers[key] = value;
    }
  }

  const fetchOptions = {
    method: req.method,
    headers,
  };

  if (req.method !== 'GET' && req.method !== 'HEAD' && req.body) {
    fetchOptions.body = typeof req.body === 'object' ? JSON.stringify(req.body) : req.body;
    if (!headers['content-type']) {
      headers['content-type'] = 'application/json';
    }
  }

  try {
    const upstreamRes = await fetch(targetUrl, fetchOptions);
    const contentType = upstreamRes.headers.get('content-type') || 'application/json';
    const data = await upstreamRes.arrayBuffer();

    res.status(upstreamRes.status);
    res.setHeader('Content-Type', contentType);
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.send(Buffer.from(data));
  } catch (err) {
    console.error('[API Proxy Error]', err);
    res.status(502).json({
      success: false,
      error: 'Unable to reach academy server via proxy. Please check connection.'
    });
  }
};
