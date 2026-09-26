const crypto = require('crypto');
const config = require('../config');
const { get, run } = require('../db');

/**
 * Base Abstract Email Provider Interface
 */
class BaseEmailProvider {
  /**
   * Send Email to destination address
   * @param {object} params
   * @param {string} params.to - Recipient email address
   * @param {string} params.subject - Email subject
   * @param {string} params.text - Plain text content
   * @param {string} [params.html] - Optional HTML content
   * @param {string} [params.otpCode] - The OTP code for metadata/logging
   * @returns {Promise<{ success: boolean, messageId?: string, error?: string }>}
   */
  async sendEmail(params) {
    throw new Error('sendEmail must be implemented by concrete Email provider');
  }
}

/**
 * Local / Development Console Email Provider
 * Logs verification code safely to runtime server console without external service dependency.
 * Never stores or returns plaintext OTP in responses.
 */
class DevConsoleEmailProvider extends BaseEmailProvider {
  constructor() {
    super();
    this.name = 'Console Development Email Provider';
    this._recentOtps = new Map(); // In-memory map for automated test verification
  }

  async sendEmail({ to, subject, text, html, otpCode }) {
    const expiresAt = new Date(Date.now() + config.emailOtpTtlMinutes * 60 * 1000).toISOString();
    this._recentOtps.set(to.toLowerCase().trim(), { code: otpCode, expiresAt });

    if (config.nodeEnv !== 'test') {
      console.log('====================================================');
      console.log(`[EMAIL DISPATCH] Recipient: ${to}`);
      console.log(`[EMAIL DISPATCH] Subject:   ${subject}`);
      console.log(`[EMAIL DISPATCH] OTP Code:  ${otpCode}`);
      console.log(`[EMAIL DISPATCH] Expires:   ${expiresAt}`);
      console.log('====================================================');
    }

    return {
      success: true,
      messageId: `dev-email-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`
    };
  }

  // Helper used exclusively by automated integration test assertions
  getTestOtp(email) {
    const record = this._recentOtps.get(email.toLowerCase().trim());
    return record ? record.code : null;
  }
}

/**
 * SMTP Email Provider (Production-ready abstraction)
 */
class SmtpEmailProvider extends BaseEmailProvider {
  constructor() {
    super();
    this.host = config.smtpHost;
    this.port = config.smtpPort;
    this.user = config.smtpUser;
    this.password = config.smtpPassword;
    this.from = config.emailFrom;
  }

  async sendEmail({ to, subject, text, html }) {
    if (!this.host || !this.user || !this.password) {
      console.error('[SmtpEmailProvider] SMTP credentials incomplete.');
      return { success: false, error: 'SMTP email credentials not configured.' };
    }

    try {
      // Dynamic require of nodemailer if installed in production environment
      const nodemailer = require('nodemailer');
      const transporter = nodemailer.createTransport({
        host: this.host,
        port: this.port,
        secure: this.port === 465,
        auth: {
          user: this.user,
          pass: this.password
        }
      });

      const info = await transporter.sendMail({
        from: this.from,
        to,
        subject,
        text,
        html: html || `<p>${text}</p>`
      });

      return { success: true, messageId: info.messageId };
    } catch (err) {
      console.error('[SmtpEmailProvider] Error dispatching email:', err.message);
      return { success: false, error: err.message };
    }
  }
}

// Provider Factory
function createEmailProvider() {
  const provider = (config.emailProvider || 'console').toLowerCase();
  switch (provider) {
    case 'smtp':
      return new SmtpEmailProvider();
    case 'console':
    default:
      return new DevConsoleEmailProvider();
  }
}

const activeEmailProvider = createEmailProvider();

/**
 * Email OTP Verification Business Service
 */
class EmailService {
  /**
   * Generates a cryptographically strong 6-digit random OTP
   */
  static generateOtpCode() {
    return crypto.randomInt(100000, 999999).toString();
  }

  /**
   * Hash OTP for safe database storage (SHA-256)
   */
  static hashOtp(otpCode) {
    return crypto.createHash('sha256').update(otpCode).digest('hex');
  }

  /**
   * Mask an email address for privacy: e.g. "rohan.verma@beastacademy.edu" -> "r***a@beastacademy.edu"
   */
  static maskEmail(email) {
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return '****@****';
    }
    const parts = email.trim().toLowerCase().split('@');
    const local = parts[0];
    const domain = parts[1];

    if (local.length <= 2) {
      return `${local[0]}***@${domain}`;
    }
    return `${local[0]}***${local[local.length - 1]}@${domain}`;
  }

  /**
   * Initiates an Email verification session using trusted database student record
   */
  static async initiateVerification({ studentIdNumber, googleUid }) {
    // 1. Fetch student and verified email strictly from trusted database
    const student = await get(
      `SELECT sp.*, u.id as user_id, u.email, u.name, u.status, u.is_active, u.role
       FROM student_profiles sp
       JOIN users u ON sp.user_id = u.id
       WHERE sp.student_id_number = ?`,
      [studentIdNumber.trim().toUpperCase()]
    );

    if (!student || student.role !== 'student') {
      return { success: false, error: 'Student record not found.', code: 'STUDENT_NOT_FOUND' };
    }

    if (!student.email || !student.email.trim() || !student.email.includes('@')) {
      return {
        success: false,
        error: 'No registered institutional email address found for this Student ID. Please contact administration.',
        code: 'EMAIL_NOT_CONFIGURED'
      };
    }

    const trustedEmail = student.email.trim().toLowerCase();
    const otpCode = this.generateOtpCode();
    const otpHash = this.hashOtp(otpCode);
    const sessionId = `eml-sess-${Date.now()}-${crypto.randomBytes(8).toString('hex')}`;
    const expiresAt = new Date(Date.now() + config.emailOtpTtlMinutes * 60 * 1000).toISOString();
    const id = `ev-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;

    // 2. Store in email_verifications table (hashed only, never plaintext)
    await run(
      `INSERT INTO email_verifications 
       (id, email, otp_hash, session_id, student_id_number, google_uid, expires_at, is_verified, attempts)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0)`,
      [id, trustedEmail, otpHash, sessionId, studentIdNumber, googleUid, expiresAt]
    );

    // 3. Dispatch via configured provider
    const dispatchResult = await activeEmailProvider.sendEmail({
      to: trustedEmail,
      subject: 'B.E.A.S.T. Academy — Your Verification Code',
      text: `B.E.A.S.T. Academy\n\nYour verification code is: ${otpCode}\n\nThis verification code is valid for ${config.emailOtpTtlMinutes} minutes.\n\nIf you did not request this code, you can safely ignore this email.`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 8px; background-color: #ffffff;">
          <h2 style="color: #0175C2; margin-top: 0; margin-bottom: 12px; font-weight: 700;">B.E.A.S.T. Academy</h2>
          <p style="font-size: 15px; color: #333333; margin-bottom: 8px;">Hello ${student.name || 'Student'},</p>
          <p style="font-size: 14px; color: #555555; margin-bottom: 16px;">Here is your B.E.A.S.T. Academy verification code:</p>
          <div style="background-color: #f0f7ff; padding: 16px; text-align: center; border-radius: 8px; margin: 20px 0; border: 1px solid #cce3f8;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #0175C2; font-family: monospace;">${otpCode}</span>
          </div>
          <p style="font-size: 13px; color: #666666; margin-bottom: 8px;">This verification code is valid for <strong>${config.emailOtpTtlMinutes} minutes</strong>.</p>
          <p style="font-size: 12px; color: #888888; margin-top: 16px; border-top: 1px solid #eeeeee; padding-top: 12px;">If you did not request this code, you can safely ignore this email.</p>
        </div>
      `,
      otpCode
    });

    return {
      success: dispatchResult.success,
      sessionId,
      expiresAt,
      emailMasked: this.maskEmail(trustedEmail),
      trustedEmail,
      error: dispatchResult.error
    };
  }

  /**
   * Verifies an Email OTP code for a given session
   */
  static async verifyOtp({ sessionId, otpCode, studentIdNumber, googleUid }) {
    const session = await get(
      `SELECT * FROM email_verifications WHERE session_id = ?`,
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
      await run(
        `UPDATE email_verifications SET attempts = attempts + 1 WHERE session_id = ?`,
        [sessionId]
      );
      return { success: false, error: 'Incorrect verification code. Please try again.' };
    }

    // Mark verified
    await run(
      `UPDATE email_verifications SET is_verified = 1 WHERE session_id = ?`,
      [sessionId]
    );

    return {
      success: true,
      email: session.email
    };
  }

  static getActiveProvider() {
    return activeEmailProvider;
  }
}

module.exports = {
  BaseEmailProvider,
  DevConsoleEmailProvider,
  SmtpEmailProvider,
  EmailService
};
