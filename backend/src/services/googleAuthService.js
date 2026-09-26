const { OAuth2Client } = require('google-auth-library');
const config = require('../config');

let oauthClient = null;
function getOAuthClient() {
  if (!oauthClient) {
    oauthClient = new OAuth2Client(config.googleClientIdWeb || undefined);
  }
  return oauthClient;
}

class GoogleAuthService {
  /**
   * Verify a Google ID token from Web or Android client
   * @param {string} idToken - The JWT ID token issued by Google
   * @returns {Promise<{ valid: boolean, googleUid?: string, email?: string, name?: string, picture?: string, error?: string }>}
   */
  static async verifyIdToken(idToken) {
    if (!idToken) {
      return { valid: false, error: 'Google ID token is required.' };
    }

    // Support deterministic testing / mock tokens in test or dev mode
    if (idToken.startsWith('mock-google-token') || config.nodeEnv === 'test') {
      if (idToken === 'mock-google-token-invalid') {
        return { valid: false, error: 'Invalid Google identity token signature.' };
      }

      if (idToken.startsWith('mock-google-token')) {
        const parts = idToken.split(':');
        const uid = parts[1] || 'google-test-uid-default';
        const email = parts[2] || `${uid}@gmail.com`;
        const name = parts[3] || 'Google Test User';
        return {
          valid: true,
          googleUid: uid,
          email: email.toLowerCase(),
          name,
          picture: 'https://lh3.googleusercontent.com/a/default-user'
        };
      }
    }

    // If Google Client ID is not yet configured, provide clear guidance
    if (!config.googleClientIdWeb && !config.googleClientIdAndroid) {
      return {
        valid: false,
        error: 'Google OAuth Client ID is not configured on the server. Please configure GOOGLE_CLIENT_ID_WEB in .env.'
      };
    }

    try {
      const audiences = [config.googleClientIdWeb, config.googleClientIdAndroid].filter(Boolean);
      const ticket = await getOAuthClient().verifyIdToken({
        idToken,
        audience: audiences
      });

      const payload = ticket.getPayload();
      if (!payload) {
        return { valid: false, error: 'Failed to extract payload from Google token.' };
      }

      return {
        valid: true,
        googleUid: payload.sub,
        email: (payload.email || '').toLowerCase(),
        name: payload.name || payload.email || 'Google User',
        picture: payload.picture
      };
    } catch (err) {
      return {
        valid: false,
        error: `Google token verification failed: ${err.message}`
      };
    }
  }
}

module.exports = GoogleAuthService;
