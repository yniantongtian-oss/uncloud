/**
 * identity.js — Uncloud device identity management.
 *
 * An identity is an ed25519 keypair generated via node:crypto and persisted
 * as PEM strings in <userhome>/.uncloud/identity.json:
 *   { publicKey, privateKey, name, createdAt }
 *
 * deviceId = first 16 hex chars of sha256(spki DER of the public key).
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

/** Default directory where Uncloud stores its state. */
export const DEFAULT_DIR = path.join(os.homedir(), '.uncloud');
export const IDENTITY_FILE = 'identity.json';

/** Absolute path of the identity file for a given state directory. */
export function identityPath(dir = DEFAULT_DIR) {
  return path.join(dir, IDENTITY_FILE);
}

/**
 * Compute the deviceId from a PEM-encoded public key:
 * first 16 hex characters of sha256(spki DER).
 *
 * @param {string} publicKeyPem PEM (spki) encoded ed25519 public key.
 * @returns {string} 16 lowercase hex characters.
 */
export function computeDeviceId(publicKeyPem) {
  const keyObject = crypto.createPublicKey(publicKeyPem);
  const der = keyObject.export({ type: 'spki', format: 'der' });
  return crypto.createHash('sha256').update(der).digest('hex').slice(0, 16);
}

/** Export the raw spki DER bytes of an identity's public key. */
export function publicKeyDer(identity) {
  return crypto.createPublicKey(identity.publicKey).export({ type: 'spki', format: 'der' });
}

/** Convenience helper: sha256 hex digest of a Buffer or string. */
export function sha256Hex(data) {
  return crypto.createHash('sha256').update(data).digest('hex');
}

/** Try to read and validate an identity file. Returns null when unusable. */
function tryLoadIdentityFile(file) {
  const raw = fs.readFileSync(file, 'utf8');
  const data = JSON.parse(raw);
  if (
    data &&
    typeof data.publicKey === 'string' &&
    typeof data.privateKey === 'string' &&
    typeof data.name === 'string'
  ) {
    // Verify the key material is actually parseable before trusting the file.
    computeDeviceId(data.publicKey);
    return data;
  }
  return null;
}

/**
 * Load the identity from disk, creating a fresh ed25519 keypair when the file
 * does not exist (or is corrupt — corrupt files are renamed to *.bak).
 *
 * @param {object} [options]
 * @param {string} [options.dir]  State directory (default ~/.uncloud).
 * @param {string} [options.name] Device name used when creating a new identity
 *                                (defaults to the OS hostname).
 * @returns {{publicKey: string, privateKey: string, name: string,
 *            createdAt: string, deviceId: string}}
 */
export function loadOrCreateIdentity(options = {}) {
  const dir = options.dir || DEFAULT_DIR;
  const file = identityPath(dir);

  let existing = null;
  try {
    existing = tryLoadIdentityFile(file);
  } catch (err) {
    if (err.code !== 'ENOENT') {
      // Corrupt or unreadable identity file: keep a backup and regenerate.
      try {
        fs.renameSync(file, file + '.bak');
      } catch {
        /* best effort */
      }
    }
  }

  if (existing === null && fs.existsSync(file)) {
    // File parsed as JSON but missed required fields: back it up as well.
    try {
      fs.renameSync(file, file + '.bak');
    } catch {
      /* best effort */
    }
  }

  if (existing) {
    return { ...existing, deviceId: computeDeviceId(existing.publicKey) };
  }

  const name = options.name || os.hostname() || 'uncloud-device';
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const identity = {
    publicKey: publicKey.export({ type: 'spki', format: 'pem' }),
    privateKey: privateKey.export({ type: 'pkcs8', format: 'pem' }),
    name,
    createdAt: new Date().toISOString(),
  };

  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(file, JSON.stringify(identity, null, 2), { mode: 0o600 });
  return { ...identity, deviceId: computeDeviceId(identity.publicKey) };
}

/** Get the deviceId for an identity object (or an object with .publicKey). */
export function getDeviceId(identity) {
  if (!identity || typeof identity.publicKey !== 'string') {
    throw new Error('getDeviceId: expected an identity object with a publicKey field');
  }
  return computeDeviceId(identity.publicKey);
}
