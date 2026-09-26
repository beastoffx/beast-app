const crypto = require('crypto');
const config = require('../config');
const { get, run } = require('../db');

/**
 * Base Abstract OTP Provider Interface
 */
class BaseOtpProvider {
  /**
   * Send OTP to the destination phone number
   * @param {string} phone - E.164 formatted phone number
   * @param {string} otpCode - 6-digit OTP code
   * @param {object} context - Additional metadata (e.g. studentIdNumber)
   * @returns {Promise<{ success: boolean, messageId?: string, error?: string }>}
   */
  async sendOtp(phone, otpCode, context = {}) {
    throw new Error('sendOtp must be implemented by concrete OTP provider');
  }

  /**
   * Optional provider-level verification (e.g. for Twilio Verify)
   */
  async verifyOtp(phone, otpCode, context = {}) {
    return { verified: true };
  }
}

/**
 * Local / Development Console OTP Provider
 * Generates true cryptographic 6-digit random OTPs without external SaaS dependency.
 * Never uses hardcoded fake OTPs. Logs code to server console for local testing.
 */
class DevConsoleOtpProvider extends BaseOtpProvider {
  constructor() {
    super();
    this.name = 'Console Development OTP Provider';
    this._recentOtps = new Map(); // In-memory map for automated test verification
  }

  async sendOtp(phone, otpCode, context = {}) {
    const expiresAt = new Date(Date.now() + config.otpTtlMinutes * 60 * 1000).toISOString();
    this._recentOtps.set(phone, { code: otpCode, expiresAt });

    if (config.nodeEnv !== 'test') {
      console.log('----------------------------------------------------');
      console.log(`[SMS/OTP DISPATCH] Destination: ${phone}`);
      console.log(`[SMS/OTP DISPATCH] Verification Code: ${otpCode}`);
      console.log(`[SMS/OTP DISPATCH] Expires: ${expiresAt}`);
      console.log('----------------------------------------------------');
    }

    return {
      success: true,
      messageId: `dev-sms-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`
    };
  }

  // Helper used exclusively by automated integration tests
  getTestOtp(phone) {
    const record = this._recentOtps.get(phone);
    return record ? record.code : null;
  }
}

/**
 * Twilio SMS / Verify Provider
 */
class TwilioOtpProvider extends BaseOtpProvider {
  constructor() {
    super();
    this.accountSid = process.env.TWILIO_ACCOUNT_SID;
    this.authToken = process.env.TWILIO_AUTH_TOKEN;
    this.serviceSid = process.env.TWILIO_SERVICE_SID;
  }

  async sendOtp(phone, otpCode, context = {}) {
    if (!this.accountSid || !this.authToken) {
      console.error('[TwilioOtpProvider] Missing TWILIO_ACCOUNT_SID or TWILIO_AUTH_TOKEN.');
      return { success: false, error: 'SMS Gateway credentials not configured.' };
    }

    try {
      // In production, instantiate twilio client dynamically
      const twilio = require('twilio')(this.accountSid, this.authToken);
      const message = await twilio.messages.create({
        body: `Your B.E.A.S.T Academy activation verification code is: ${otpCode}. Valid for ${config.otpTtlMinutes} minutes. Do not share this code.`,
        to: phone,
        from: process.env.TWILIO_PHONE_NUMBER
      });
      return { success: true, messageId: message.sid };
    } catch (err) {
      console.error('[TwilioOtpProvider] Error dispatching SMS:', err.message);
      return { success: false, error: err.message };
    }
  }
}

/**
 * MSG91 SMS Provider (India)
 */
class Msg91OtpProvider extends BaseOtpProvider {
  constructor() {
    super();
    this.authKey = process.env.MSG91_AUTH_KEY;
    this.templateId = process.env.MSG91_TEMPLATE_ID;
  }

  async sendOtp(phone, otpCode, context = {}) {
    if (!this.authKey) {
      console.error('[Msg91OtpProvider] Missing MSG91_AUTH_KEY.');
      return { success: false, error: 'SMS Gateway credentials not configured.' };
    }

    try {
      const cleanPhone = phone.replace(/[^0-9]/g, '');
      const response = await fetch(`https://api.msg91.com/api/v5/otp?template_id=${this.templateId}&mobile=${cleanPhone}&authkey=${this.authKey}&otp=${otpCode}`, {
        method: 'POST'
      });
      const data = await response.json();
      return { success: data.type === 'success', messageId: data.request_id, error: data.message };
    } catch (err) {
      console.error('[Msg91OtpProvider] Error dispatching OTP:', err.message);
      return { success: false, error: err.message };
    }
  }
}

// Provider Factory
function createOtpProvider() {
  const provider = (config.otpProvider || '').toLowerCase();
  switch (provider) {
    case 'twilio':
      return new TwilioOtpProvider();
    case 'msg91':
      return new Msg91OtpProvider();
    case 'console':
    default:
      return new DevConsoleOtpProvider();
  }
}

const activeOtpProvider = createOtpProvider();

/**
 * OTP Verification Business Service
 */
class OtpService {
  /**
   * Generates a cryptographically strong 6-digit OTP
   */
  static generateOtpCode() {
    return crypto.randomInt(100000, 999999).toString();
  }

  /**
   * Hash OTP for safe database storage
   */
  static hashOtp(otpCode) {
    return crypto.createHash('sha256').update(otpCode).digest('hex');
  }

  /**
   * Initiates a phone verification session
   */
  static async initiateVerification({ phone, studentIdNumber, googleUid }) {
    const otpCode = this.generateOtpCode();
    const otpHash = this.hashOtp(otpCode);
    const sessionId = `otp-sess-${Date.now()}-${crypto.randomBytes(8).toString('hex')}`;
    const expiresAt = new Date(Date.now() + config.otpTtlMinutes * 60 * 1000).toISOString();
    const id = `pv-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

    // Store in phone_verifications table
    run(
      `INSERT INTO phone_verifications 
       (id, phone, otp_hash, session_id, student_id_number, google_uid, expires_at, is_verified, attempts)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0)`,
      [id, phone, otpHash, sessionId, studentIdNumber, googleUid, expiresAt]
    );

    // Dispatch via configured provider
    const dispatchResult = await activeOtpProvider.sendOtp(phone, otpCode, { studentIdNumber });

    return {
      success: dispatchResult.success,
      sessionId,
      expiresAt,
      error: dispatchResult.error
    };
  }

  /**
   * Verifies an OTP code for a given session
   */
  static verifyOtp({ sessionId, otpCode, studentIdNumber, googleUid }) {
    const session = get(
      `SELECT * FROM phone_verifications WHERE session_id = ?`,
      [sessionId]
    );

    if (!session) {
      return { success: false, error: 'Invalid verification session.' };
    }

    if (session.is_verified) {
      return { success: false, error: 'Verification code has already been used.' };
    }

    if (session.attempts >= 5) {
      return { success: false, error: 'Maximum verification attempts exceeded. Please request a new code.' };
    }

    // Check expiration
    const now = new Date();
    const expiry = new Date(session.expires_at);
    if (now > expiry) {
      return { success: false, error: 'Verification code has expired. Please request a new code.' };
    }

    // Verify context
    if (session.student_id_number !== studentIdNumber || session.google_uid !== googleUid) {
      return { success: false, error: 'Verification session identity mismatch.' };
    }

    // Compare hash
    const submittedHash = this.hashOtp(otpCode.trim());
    if (submittedHash !== session.otp_hash) {
      run(
        `UPDATE phone_verifications SET attempts = attempts + 1 WHERE session_id = ?`,
        [sessionId]
      );
      return { success: false, error: 'Incorrect verification code. Please try again.' };
    }

    // Mark verified
    run(
      `UPDATE phone_verifications SET is_verified = 1 WHERE session_id = ?`,
      [sessionId]
    );

    return {
      success: true,
      phone: session.phone
    };
  }

  static getActiveProvider() {
    return activeOtpProvider;
  }
}

module.exports = {
  BaseOtpProvider,
  DevConsoleOtpProvider,
  TwilioOtpProvider,
  Msg91OtpProvider,
  OtpService
};
