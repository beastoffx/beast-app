const fs = require('fs');
const path = require('path');
const config = require('../config');

class BaseStorageProvider {
  async uploadFile({ bucket, key, buffer, mimetype }) {
    throw new Error('uploadFile must be implemented');
  }

  async getAuthorizedDownloadUrl({ bucket, key, expiresInSeconds = 3600 }) {
    throw new Error('getAuthorizedDownloadUrl must be implemented');
  }

  async deleteFile({ bucket, key }) {
    throw new Error('deleteFile must be implemented');
  }
}

/**
 * Local Filesystem Storage Provider (Development & Local fallback)
 */
class LocalStorageProvider extends BaseStorageProvider {
  constructor() {
    super();
    this.baseDir = config.uploadDir;
  }

  _getTargetPath(bucket, key) {
    const safeKey = path.basename(key);
    const bucketDir = path.join(this.baseDir, bucket);
    if (!fs.existsSync(bucketDir)) {
      fs.mkdirSync(bucketDir, { recursive: true });
    }
    return path.join(bucketDir, safeKey);
  }

  async uploadFile({ bucket, key, buffer, mimetype }) {
    const targetPath = this._getTargetPath(bucket, key);
    fs.writeFileSync(targetPath, buffer);
    return {
      success: true,
      storageProvider: 'local',
      bucket,
      key,
      url: `/uploads/${bucket}/${path.basename(key)}`
    };
  }

  async getAuthorizedDownloadUrl({ bucket, key, expiresInSeconds = 3600 }) {
    const safeKey = path.basename(key);
    // In local dev, return the static endpoint with a time-limited signed token reference if needed
    return {
      success: true,
      storageProvider: 'local',
      url: `/uploads/${bucket}/${safeKey}`
    };
  }

  async deleteFile({ bucket, key }) {
    const targetPath = this._getTargetPath(bucket, key);
    if (fs.existsSync(targetPath)) {
      fs.unlinkSync(targetPath);
    }
    return { success: true };
  }
}

/**
 * Supabase Storage Provider (Cloud Production)
 * Manages private buckets: beast-resources and beast-doubts using server-side service role key.
 */
class SupabaseStorageProvider extends BaseStorageProvider {
  constructor() {
    super();
    const { createClient } = require('@supabase/supabase-js');
    this.client = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });
  }

  async uploadFile({ bucket, key, buffer, mimetype }) {
    try {
      const { data, error } = await this.client.storage
        .from(bucket)
        .upload(key, buffer, {
          contentType: mimetype,
          upsert: true
        });

      if (error) {
        throw error;
      }

      return {
        success: true,
        storageProvider: 'supabase',
        bucket,
        key: data.path
      };
    } catch (err) {
      console.error(`[SupabaseStorage] Upload error to bucket "${bucket}":`, err.message);
      return { success: false, error: err.message };
    }
  }

  async getAuthorizedDownloadUrl({ bucket, key, expiresInSeconds = 3600 }) {
    // If path refers to a local file or local development directory
    if (key && (key.startsWith('/uploads') || key.startsWith('uploads/'))) {
      return {
        success: true,
        storageProvider: 'local',
        url: key.startsWith('/') ? key : `/${key}`
      };
    }

    try {
      const { data, error } = await this.client.storage
        .from(bucket)
        .createSignedUrl(key, expiresInSeconds);

      if (error) {
        // Fallback for local files/fixtures during testing or prior to media migration
        return {
          success: true,
          storageProvider: 'local',
          url: `/uploads/${bucket}/${path.basename(key)}`
        };
      }

      return {
        success: true,
        storageProvider: 'supabase',
        url: data.signedUrl,
        expiresInSeconds
      };
    } catch (err) {
      return {
        success: true,
        storageProvider: 'local',
        url: `/uploads/${bucket}/${path.basename(key)}`
      };
    }
  }

  async deleteFile({ bucket, key }) {
    try {
      const { error } = await this.client.storage.from(bucket).remove([key]);
      if (error) throw error;
      return { success: true };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }
}

// Provider Factory
function createStorageProvider() {
  if (config.supabaseUrl && config.supabaseServiceRoleKey) {
    return new SupabaseStorageProvider();
  }
  return new LocalStorageProvider();
}

const activeStorageProvider = createStorageProvider();

module.exports = {
  BaseStorageProvider,
  LocalStorageProvider,
  SupabaseStorageProvider,
  StorageService: activeStorageProvider
};
