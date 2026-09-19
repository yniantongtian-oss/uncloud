/**
 * pairing.js — pairing payload encoding/decoding (for QR codes).
 *
 * Payload format:
 *   'uncloud://' + base64url(JSON.stringify({
 *     v: 1, deviceId, name, host, port, pub: <base64url of spki DER>
 *   }))
 */

export const PAIRING_PREFIX = 'uncloud://';
export const PAIRING_VERSION = 1;

/**
 * Encode a pairing payload.
 *
 * @param {object} info
 * @param {string} info.deviceId      16-hex-char device id.
 * @param {string} info.name          Device display name.
 * @param {string} info.host          IPv4/IPv6 address or hostname.
 * @param {number} info.port          TCP port of the transfer server.
 * @param {Buffer} info.publicKeyDer  spki DER bytes of the device public key.
 * @returns {string} payload starting with 'uncloud://'
 */
export function encodePairingPayload({ deviceId, name, host, port, publicKeyDer } = {}) {
  if (typeof deviceId !== 'string' || deviceId.length === 0) {
    throw new Error('encodePairingPayload: deviceId must be a non-empty string');
  }
  if (typeof name !== 'string' || name.length === 0) {
    throw new Error('encodePairingPayload: name must be a non-empty string');
  }
  if (typeof host !== 'string' || host.length === 0) {
    throw new Error('encodePairingPayload: host must be a non-empty string');
  }
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('encodePairingPayload: port must be an integer between 1 and 65535');
  }
  if (!Buffer.isBuffer(publicKeyDer) || publicKeyDer.length === 0) {
    throw new Error('encodePairingPayload: publicKeyDer must be a non-empty Buffer');
  }

  const obj = {
    v: PAIRING_VERSION,
    deviceId,
    name,
    host,
    port,
    pub: publicKeyDer.toString('base64url'),
  };
  return PAIRING_PREFIX + Buffer.from(JSON.stringify(obj), 'utf8').toString('base64url');
}

/**
 * Decode and validate a pairing payload.
 *
 * @param {string} payload
 * @returns {{v:number, deviceId:string, name:string, host:string, port:number,
 *            pub:string, publicKeyDer:Buffer}}
 * @throws {Error} with a friendly, human-readable message on invalid input.
 */
export function decodePairingPayload(payload) {
  if (typeof payload !== 'string' || !payload.startsWith(PAIRING_PREFIX)) {
    throw new Error(`Invalid pairing payload: expected a string starting with "${PAIRING_PREFIX}"`);
  }
  const encoded = payload.slice(PAIRING_PREFIX.length).trim();
  if (encoded.length === 0) {
    throw new Error('Invalid pairing payload: payload body is empty');
  }

  let obj;
  try {
    obj = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8'));
  } catch {
    throw new Error('Invalid pairing payload: could not decode base64url-encoded JSON');
  }

  if (!obj || typeof obj !== 'object') {
    throw new Error('Invalid pairing payload: decoded value is not a JSON object');
  }
  if (obj.v !== PAIRING_VERSION) {
    throw new Error(`Unsupported pairing payload version: ${obj.v} (expected ${PAIRING_VERSION})`);
  }
  if (typeof obj.deviceId !== 'string' || obj.deviceId.length === 0) {
    throw new Error('Invalid pairing payload: missing or invalid "deviceId"');
  }
  if (typeof obj.name !== 'string' || obj.name.length === 0) {
    throw new Error('Invalid pairing payload: missing or invalid "name"');
  }
  if (typeof obj.host !== 'string' || obj.host.length === 0) {
    throw new Error('Invalid pairing payload: missing or invalid "host"');
  }
  if (!Number.isInteger(obj.port) || obj.port < 1 || obj.port > 65535) {
    throw new Error('Invalid pairing payload: "port" must be an integer between 1 and 65535');
  }
  if (typeof obj.pub !== 'string' || obj.pub.length === 0) {
    throw new Error('Invalid pairing payload: missing or invalid "pub" (public key)');
  }

  let publicKeyDer;
  try {
    publicKeyDer = Buffer.from(obj.pub, 'base64url');
  } catch {
    throw new Error('Invalid pairing payload: "pub" is not valid base64url');
  }
  if (publicKeyDer.length === 0) {
    throw new Error('Invalid pairing payload: "pub" decoded to an empty key');
  }

  return {
    v: obj.v,
    deviceId: obj.deviceId,
    name: obj.name,
    host: obj.host,
    port: obj.port,
    pub: obj.pub,
    publicKeyDer,
  };
}
