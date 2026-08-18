const crypto = require('crypto');
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const gunzip = promisify(zlib.gunzip);

class CryptoManager {
  static _instance = null;

  constructor() {
    if (this._instance) {
      return this._instance;
    }

    this.privateKeyPem = null;
    this.publicKeyPem = null;
    this._loadKeys();

    this._instance = this;
  }

  static getInstance() {
    if (!this._instance) {
      this._instance = new CryptoManager();
      return this._instance
    }
    return this._instance;
  }

  /**
   * Load keys from root directory
   * Creates them if they don't exist
   */
  _loadKeys() {
    const rootDir = process.cwd();
    console.log(rootDir);
    const privateKeyPath = path.join(rootDir, 'private.key');
    const publicKeyPath = path.join(rootDir, 'public.key');

    // Load or generate keys
    if (fs.existsSync(privateKeyPath) && fs.existsSync(publicKeyPath)) {
      this.privateKeyPem = fs.readFileSync(privateKeyPath, 'utf8');
      this.publicKeyPem = fs.readFileSync(publicKeyPath, 'utf8');
      console.log('🔑 Keys loaded successfully from files.');
    } else {
      console.log('⚠️  Key files not found. Generating new RSA key pair...');
      const { publicKey, privateKey } = this._generateAndSaveKeys(privateKeyPath, publicKeyPath);
      this.privateKeyPem = privateKey;
      this.publicKeyPem = publicKey;
    }
  }

  /**
   * Generate and save key pair
   */
  _generateAndSaveKeys(privateKeyPath, publicKeyPath) {
    const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });

    // Save keys
    fs.writeFileSync(privateKeyPath, privateKey);
    fs.writeFileSync(publicKeyPath, publicKey);

    console.log('✅ New RSA key pair generated and saved:');
    console.log('   • private.key');
    console.log('   • public.key');
    console.log('\n⚠️  Keep private.key secure and never commit it!');

    return { publicKey, privateKey };
  }

  /**
   * Decrypt JSON - Takes only encryptedBase64
   */
  async decryptJson(encryptedBase64) {
    if (!this.privateKeyPem) {
      throw new Error('Private key not loaded');
    }

    try {
      const combined = Buffer.from(encryptedBase64, 'base64');
      console.log(`[DEBUG] Total encrypted length: ${combined.length} bytes`);

      const rsaKeySize = 256;
      if (combined.length < rsaKeySize + 12) {
        throw new Error(`Data too short. Expected at least ${rsaKeySize + 12}, got ${combined.length}`);
      }

      const rsaEncryptedAesKey = combined.slice(0, rsaKeySize);
      const iv = combined.slice(rsaKeySize, rsaKeySize + 12);
      const cipherText = combined.slice(rsaKeySize + 12);

      console.log(`[DEBUG] RSA encrypted key length: ${rsaEncryptedAesKey.length}`);
      console.log(`[DEBUG] IV length: ${iv.length}`);
      console.log(`[DEBUG] Ciphertext length: ${cipherText.length}`);

      // Decrypt AES key
      const aesKey = crypto.privateDecrypt(
        {
          key: this.privateKeyPem,
          padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
          oaepHash: 'sha256',
          oaepLabel: Buffer.alloc(0),
        },
        rsaEncryptedAesKey
      );

      console.log(`[DEBUG] Successfully decrypted AES key (${aesKey.length} bytes)`);

      // AES Decryption
      const decipher = crypto.createDecipheriv('aes-256-gcm', aesKey, iv);
      const tagLength = 16;
      const cipherTextWithTag = cipherText;

      if (cipherTextWithTag.length < tagLength) {
        throw new Error('Ciphertext too short for GCM tag');
      }

      const encryptedData = cipherTextWithTag.slice(0, -tagLength);
      const authTag = cipherTextWithTag.slice(-tagLength);

      decipher.setAuthTag(authTag);

      const decryptedCompressed = Buffer.concat([
        decipher.update(encryptedData),
        decipher.final()
      ]);

      console.log('✅ AES-GCM decryption successful');

      const decompressed = await gunzip(decryptedCompressed);
      const jsonString = decompressed.toString('utf8');

      console.log("[DEBUG] stringified json - ", jsonString);
      
      return JSON.parse(jsonString);
    } catch (error) {
      console.error('Decryption failed:', error.message);
      if (error.message.includes('oaep')) {
        console.error('💡 Hint: RSA padding mismatch or corrupted RSA-encrypted key part');
      }
      throw error;
    }
  }
  /**
   * Get Public Key (for sharing with Dart client)
   */
  getPublicKey() {
    return this.publicKeyPem;
  }
}

module.exports = CryptoManager;