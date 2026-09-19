/**
 * transfer.js — TCP file transfer (sender and receiver).
 *
 * Protocol:
 *   1. Sender connects and sends one header line, terminated by '\n':
 *        {"name": "...", "size": <bytes>, "sha256": "<64 hex chars>"}
 *   2. Sender streams the raw file bytes (64 KB chunks).
 *   3. Receiver streams the bytes to <inboxDir>/<sanitized name>, computes
 *      sha256 while writing, compares it to the header, and replies with a
 *      single line:
 *        {"ok": true}  or  {"ok": false, "reason": "..."}
 */
import net from 'node:net';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';

export const CHUNK_SIZE = 64 * 1024;
const HEADER_MAX_BYTES = 64 * 1024;
const SHA256_HEX_RE = /^[0-9a-f]{64}$/i;

/**
 * Sanitize a received file name against path traversal and illegal chars.
 * Strips any directory components (both '/' and '\') and replaces control
 * characters and Windows-illegal characters with underscores.
 */
export function sanitizeFileName(name) {
  let base = String(name ?? '').split(/[\\/]/).pop() ?? '';
  // eslint-disable-next-line no-control-regex
  base = base.replace(/[\x00-\x1f<>:"|?*]/g, '_').trim();
  if (!base || base === '.' || base === '..') {
    base = `unnamed-${Date.now()}`;
  }
  return base;
}

/** Pick a non-existing destination path inside inboxDir ("name (1).ext" style). */
function uniqueDestination(inboxDir, safeName) {
  let candidate = path.join(inboxDir, safeName);
  if (!fs.existsSync(candidate)) return candidate;
  const ext = path.extname(safeName);
  const stem = safeName.slice(0, safeName.length - ext.length);
  for (let i = 1; ; i++) {
    candidate = path.join(inboxDir, `${stem} (${i})${ext}`);
    if (!fs.existsSync(candidate)) return candidate;
  }
}

function validateHeader(h) {
  if (!h || typeof h !== 'object' || Array.isArray(h)) {
    return 'Invalid header: expected a JSON object';
  }
  if (typeof h.name !== 'string' || h.name.length === 0) {
    return 'Invalid header: "name" must be a non-empty string';
  }
  if (!Number.isSafeInteger(h.size) || h.size < 0) {
    return 'Invalid header: "size" must be a non-negative integer';
  }
  if (typeof h.sha256 !== 'string' || !SHA256_HEX_RE.test(h.sha256)) {
    return 'Invalid header: "sha256" must be 64 hex characters';
  }
  return null;
}

/** Handle one incoming transfer connection. */
function handleConnection(socket, { inboxDir, onProgress, onFileReceived }) {
  socket.setNoDelay(true);

  let headerChunks = [];
  let headerLen = 0;
  let header = null;
  let received = 0;
  const hasher = crypto.createHash('sha256');
  let out = null;
  let destPath = null;
  let finished = false;
  let completing = false;

  function reply(obj) {
    try {
      socket.write(JSON.stringify(obj) + '\n', () => {
        try {
          socket.end();
        } catch {
          /* already closed */
        }
      });
    } catch {
      try {
        socket.destroy();
      } catch {
        /* ignore */
      }
    }
  }

  function cleanupPartial() {
    if (out) {
      try {
        out.destroy();
      } catch {
        /* ignore */
      }
      out = null;
    }
    if (destPath) {
      const p = destPath;
      destPath = null;
      fs.rm(p, { force: true }, () => {});
    }
  }

  function fail(reason) {
    if (finished) return;
    finished = true;
    if (out) {
      try {
        out.destroy();
      } catch {
        /* ignore */
      }
      out = null;
    }
    const p = destPath;
    destPath = null;
    // Reply only after the partial file is removed, so a peer that receives
    // ok:false can be sure no corrupt file remains in the inbox.
    if (p) {
      fs.rm(p, { force: true }, () => reply({ ok: false, reason }));
    } else {
      reply({ ok: false, reason });
    }
  }

  function succeed() {
    if (finished) return;
    finished = true;
    const record = {
      name: path.basename(destPath),
      size: header.size,
      sha256: header.sha256.toLowerCase(),
      direction: 'received',
      peerDeviceId: null, // The transfer protocol carries no device identity.
      remoteAddress: socket.remoteAddress ?? null,
      timestamp: new Date().toISOString(),
    };
    destPath = null; // Do not delete on later cleanup paths.
    out = null;
    try {
      onFileReceived?.(record);
    } catch {
      /* listener errors must not break the transfer */
    }
    reply({ ok: true });
  }

  function completeFile() {
    if (completing || finished) return;
    completing = true;
    const digest = hasher.digest('hex');
    out.end();
    // Wait for 'close' so the file descriptor is released (matters on Windows
    // when deleting mismatched files).
    out.once('close', () => {
      if (finished) return;
      if (digest !== header.sha256.toLowerCase()) {
        fail(`Hash mismatch: expected ${header.sha256.toLowerCase()}, got ${digest}`);
        return;
      }
      succeed();
    });
  }

  socket.on('data', (chunk) => {
    if (finished || completing) return;
    let buf = chunk;

    if (!header) {
      headerChunks.push(chunk);
      headerLen += chunk.length;
      if (headerLen > HEADER_MAX_BYTES) {
        fail('Header line too large (max 64 KB)');
        return;
      }
      const all = Buffer.concat(headerChunks);
      const nl = all.indexOf(0x0a); // '\n'
      if (nl === -1) return; // Wait for more header bytes.
      const line = all.subarray(0, nl).toString('utf8').trim();
      buf = all.subarray(nl + 1);
      headerChunks = [];

      try {
        header = JSON.parse(line);
      } catch {
        fail('Invalid header: not valid JSON');
        return;
      }
      const err = validateHeader(header);
      if (err) {
        fail(err);
        return;
      }

      const safeName = sanitizeFileName(header.name);
      destPath = uniqueDestination(inboxDir, safeName);
      out = fs.createWriteStream(destPath);
      out.on('error', (werr) => fail(`Could not write to inbox: ${werr.message}`));

      if (buf.length === 0) {
        if (header.size === 0) completeFile();
        return;
      }
      // Fall through: bytes after the newline are already file data.
    }

    const remaining = header.size - received;
    const slice = remaining >= buf.length ? buf : buf.subarray(0, remaining);
    if (slice.length > 0) {
      received += slice.length;
      hasher.update(slice);
      try {
        onProgress?.({ received, total: header.size, name: header.name });
      } catch {
        /* listener errors must not break the transfer */
      }
      if (!out.write(slice)) {
        socket.pause();
        out.once('drain', () => {
          if (!finished) socket.resume();
        });
      }
    }
    if (received >= header.size) completeFile();
  });

  socket.on('error', () => {
    if (!finished) {
      finished = true;
      cleanupPartial();
    }
  });

  socket.on('close', () => {
    if (!finished) {
      // Peer disconnected mid-transfer: drop the partial file.
      finished = true;
      cleanupPartial();
    }
  });
}

/**
 * Start the receiver server. Handles multiple sequential connections.
 *
 * @param {object} options
 * @param {number} [options.port]        TCP port (default 47778, 0 = ephemeral).
 * @param {string} [options.host]        Bind address (default: all interfaces).
 * @param {string} options.inboxDir      Directory where files are stored.
 * @param {Function} [options.onProgress]    ({received, total, name}) => void
 * @param {Function} [options.onFileReceived] (record) => void
 * @returns {net.Server} Attach 'error'/'listening' handlers as usual.
 */
export function startServer({ port = 47778, host, inboxDir, onProgress, onFileReceived } = {}) {
  if (!inboxDir || typeof inboxDir !== 'string') {
    throw new Error('startServer: inboxDir is required');
  }
  fs.mkdirSync(inboxDir, { recursive: true });

  const server = net.createServer((socket) => {
    try {
      handleConnection(socket, { inboxDir, onProgress, onFileReceived });
    } catch {
      try {
        socket.destroy();
      } catch {
        /* ignore */
      }
    }
  });
  server.listen(port, host);
  return server;
}

/** Hash a file with sha256, streaming in 64 KB chunks. */
async function hashFile(filePath) {
  return new Promise((resolve, reject) => {
    const hasher = crypto.createHash('sha256');
    const rs = fs.createReadStream(filePath, { highWaterMark: CHUNK_SIZE });
    rs.on('data', (chunk) => hasher.update(chunk));
    rs.on('end', () => resolve(hasher.digest('hex')));
    rs.on('error', reject);
  });
}

/**
 * Send a file to a peer.
 *
 * @param {object} options
 * @param {string} options.host       Peer host.
 * @param {number} options.port       Peer port.
 * @param {string} options.filePath   Local file to send.
 * @param {Function} [options.onProgress] ({sent, total, name}) => void
 * @param {number} [options.timeoutMs]    Inactivity timeout (default 15000).
 * @returns {Promise<{reply: {ok:boolean, reason?:string},
 *                    file: {name:string, size:number, sha256:string}}>}
 */
export async function sendFile({ host, port, filePath, onProgress, timeoutMs = 15000 } = {}) {
  if (!host || typeof host !== 'string') {
    throw new Error('sendFile: host is required');
  }
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('sendFile: port must be an integer between 1 and 65535');
  }

  let stat;
  try {
    stat = await fsp.stat(filePath);
  } catch {
    throw new Error(`File not found: ${filePath}`);
  }
  if (!stat.isFile()) {
    throw new Error(`Not a regular file: ${filePath}`);
  }

  const size = stat.size;
  const name = path.basename(filePath);
  // The header carries the hash, so it must be computed before connecting.
  const sha256 = await hashFile(filePath);

  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host, port });
    let settled = false;
    let responseBuf = '';

    const fail = (err) => {
      if (settled) return;
      settled = true;
      try {
        socket.destroy();
      } catch {
        /* ignore */
      }
      reject(err);
    };
    const done = (replyObj) => {
      if (settled) return;
      settled = true;
      try {
        socket.end();
      } catch {
        /* ignore */
      }
      resolve({ reply: replyObj, file: { name, size, sha256 } });
    };

    socket.setTimeout(timeoutMs, () =>
      fail(new Error(`Connection to ${host}:${port} timed out after ${timeoutMs} ms`)),
    );

    socket.on('error', (err) => {
      if (err.code === 'ECONNREFUSED') {
        fail(new Error(`Connection refused by ${host}:${port} — is the peer running "uncloud serve"?`));
      } else {
        fail(new Error(`Transfer to ${host}:${port} failed: ${err.message}`));
      }
    });

    socket.on('connect', () => {
      socket.write(JSON.stringify({ name, size, sha256 }) + '\n');
      const rs = fs.createReadStream(filePath, { highWaterMark: CHUNK_SIZE });
      let sent = 0;
      rs.on('data', (chunk) => {
        sent += chunk.length;
        try {
          onProgress?.({ sent, total: size, name });
        } catch {
          /* listener errors must not break the transfer */
        }
        if (!socket.write(chunk)) rs.pause();
      });
      rs.on('end', () => {
        // All bytes sent; the receiver's reply arrives via socket 'data'.
      });
      rs.on('error', (err) => fail(new Error(`Could not read ${filePath}: ${err.message}`)));
      socket.on('drain', () => rs.resume());
    });

    socket.on('data', (chunk) => {
      responseBuf += chunk.toString('utf8');
      const nl = responseBuf.indexOf('\n');
      if (nl === -1) return;
      const line = responseBuf.slice(0, nl).trim();
      let replyObj;
      try {
        replyObj = JSON.parse(line);
      } catch {
        fail(new Error('Receiver sent an invalid response'));
        return;
      }
      done(replyObj);
    });
  });
}

