#!/usr/bin/env node
/**
 * uncloud — CLI for the Uncloud core engine.
 *
 * Commands:
 *   id                                  Show deviceId, name and key fingerprint
 *   scan [--timeout ms]                 Discover peers on the LAN
 *   pair [--port 47778]                 Print this device's pairing payload
 *   serve [--port 47778] [--dir DIR]    Run the receiver server + discovery
 *   send <file> --to <host:port>        Send a file to a peer
 *   demo                                Self-contained loopback demo
 *   help                                Show this help
 */
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import crypto from 'node:crypto';
import { parseArgs } from 'node:util';

import { loadOrCreateIdentity, publicKeyDer, sha256Hex } from '../src/identity.js';
import { startDiscovery, DISCOVERY_PORT } from '../src/discovery.js';
import { encodePairingPayload } from '../src/pairing.js';
import { startServer, sendFile } from '../src/transfer.js';
import { IndexDB } from '../src/indexdb.js';

const DEFAULT_PORT = 47778;
const DEFAULT_INBOX = './uncloud-inbox';
const INDEX_FILE = path.join(os.homedir(), '.uncloud', 'index.json');

const HELP = `uncloud — local-first file sync between phone and PC (no cloud)

Usage: uncloud <command> [options]

Commands:
  id                                Show deviceId, name and key fingerprint
  scan [--timeout ms]               Discover peers on the LAN (default 4000 ms)
  pair [--port 47778]               Print this device's pairing payload (for QR)
  serve [--port 47778] [--dir ./uncloud-inbox]
                                    Run the receiver server + announce via discovery
  send <file> --to <host:port>      Send a file (progress bar on stderr)
  demo                              Self-contained loopback demo on 127.0.0.1
  help                              Show this help

Examples:
  uncloud serve --port 47778 --dir ./uncloud-inbox
  uncloud scan --timeout 5000
  uncloud send photo.jpg --to 192.168.1.42:47778
`;

function printError(message) {
  console.error(`uncloud: error: ${message}`);
}

/** Parse options for a command, exiting with a clear message on bad input. */
function parseCommandArgs(args, options, usage) {
  try {
    return parseArgs({ args, options, allowPositionals: true, strict: true });
  } catch (err) {
    printError(`${err.message}\n${usage}`);
    process.exit(2);
  }
}

/** Parse an integer option value with a clear error message. */
function parseIntOption(value, flagName) {
  const n = Number.parseInt(value, 10);
  if (!Number.isInteger(n)) {
    printError(`--${flagName} must be an integer, got "${value}"`);
    process.exit(2);
  }
  return n;
}

/** Load this device's identity or exit with a clear message. */
function requireIdentity() {
  try {
    return loadOrCreateIdentity();
  } catch (err) {
    printError(`could not load/create identity: ${err.message}`);
    process.exit(1);
  }
}

/** Full fingerprint of the device public key (sha256 of spki DER). */
function fingerprint(identity) {
  return sha256Hex(publicKeyDer(identity));
}

/** Format bytes as a human-readable string. */
function formatBytes(n) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 ** 2) return `${(n / 1024).toFixed(1)} KB`;
  if (n < 1024 ** 3) return `${(n / 1024 ** 2).toFixed(1)} MB`;
  return `${(n / 1024 ** 3).toFixed(2)} GB`;
}

/** Draw a progress bar on stderr (single line, overwritten via \r). */
function progressBar(sent, total) {
  const width = 30;
  const ratio = total > 0 ? Math.min(1, sent / total) : 1;
  const filled = Math.round(ratio * width);
  const bar = '\u2588'.repeat(filled) + '\u2591'.repeat(width - filled);
  process.stderr.write(
    `\r[${bar}] ${String(Math.round(ratio * 100)).padStart(3)}% ${formatBytes(sent)}/${formatBytes(total)}`,
  );
}

/** Resolve the primary LAN IPv4 address (best effort, fallback 127.0.0.1). */
function primaryLanAddress() {
  for (const addrs of Object.values(os.networkInterfaces())) {
    for (const addr of addrs ?? []) {
      if (addr.family === 'IPv4' && !addr.internal) return addr.address;
    }
  }
  return '127.0.0.1';
}

/** Record a transfer in the local index (best effort). */
function recordInIndex(record) {
  try {
    new IndexDB(INDEX_FILE).add(record);
  } catch (err) {
    console.error(`uncloud: warning: could not update index: ${err.message}`);
  }
}
/* ------------------------------------------------------------------ */
/* Commands                                                           */
/* ------------------------------------------------------------------ */

function cmdId() {
  const identity = requireIdentity();
  console.log(`Name:        ${identity.name}`);
  console.log(`Device ID:   ${identity.deviceId}`);
  console.log(`Fingerprint: ${fingerprint(identity)}`);
  console.log(`Created at:  ${identity.createdAt}`);
  console.log(`Stored in:   ${path.join(os.homedir(), '.uncloud', 'identity.json')}`);
}

async function cmdScan(args) {
  const { values } = parseCommandArgs(
    args,
    { timeout: { type: 'string', default: '4000' } },
    'Usage: uncloud scan [--timeout ms]',
  );
  const timeoutMs = parseIntOption(values.timeout, 'timeout');
  const identity = requireIdentity();

  console.error(`Scanning for peers on the LAN for ${timeoutMs} ms (multicast group 239.255.77.77:${DISCOVERY_PORT})...`);
  const discovery = startDiscovery({ port: 0, name: identity.name, deviceId: identity.deviceId });
  discovery.on('error', (err) => {
    printError(`discovery error: ${err.message}`);
    discovery.stop();
    process.exit(1);
  });

  await new Promise((resolve) => setTimeout(resolve, timeoutMs));
  const peers = discovery.peers;
  discovery.stop();

  if (peers.length === 0) {
    console.log('No peers found.');
    return;
  }

  const rows = peers.map((p) => [p.deviceId, p.name, p.host, String(p.port)]);
  const headers = ['DEVICE ID', 'NAME', 'HOST', 'PORT'];
  const widths = headers.map((h, i) => Math.max(h.length, ...rows.map((r) => r[i].length)));
  const line = (cols) => cols.map((c, i) => String(c).padEnd(widths[i])).join('  ');
  console.log(line(headers));
  console.log(widths.map((w) => '-'.repeat(w)).join('  '));
  for (const row of rows) console.log(line(row));
}

function cmdPair(args) {
  const { values } = parseCommandArgs(
    args,
    { port: { type: 'string', default: String(DEFAULT_PORT) } },
    'Usage: uncloud pair [--port 47778]',
  );
  const port = parseIntOption(values.port, 'port');
  const identity = requireIdentity();
  const host = primaryLanAddress();

  const payload = encodePairingPayload({
    deviceId: identity.deviceId,
    name: identity.name,
    host,
    port,
    publicKeyDer: publicKeyDer(identity),
  });

  console.log(`Pairing payload for "${identity.name}" (${host}:${port}):`);
  console.log(payload);
  console.error('\nTip: encode this string as a QR code and scan it from your phone.');
}
async function cmdServe(args) {
  const { values } = parseCommandArgs(
    args,
    {
      port: { type: 'string', default: String(DEFAULT_PORT) },
      dir: { type: 'string', default: DEFAULT_INBOX },
    },
    'Usage: uncloud serve [--port 47778] [--dir ./uncloud-inbox]',
  );
  const port = parseIntOption(values.port, 'port');
  const inboxDir = path.resolve(values.dir);
  const identity = requireIdentity();

  const server = startServer({
    port,
    inboxDir,
    onFileReceived: (record) => {
      console.log(
        `[${record.timestamp}] received ${record.name} (${formatBytes(record.size)}) from ${record.remoteAddress ?? 'unknown'}`,
      );
      recordInIndex(record);
    },
  });

  let discovery = null;
  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      printError(`port ${port} is already in use — choose another with --port`);
    } else {
      printError(`server error: ${err.message}`);
    }
    process.exit(1);
  });
  server.on('listening', () => {
    const addr = server.address();
    console.log(`uncloud serve — receiving files on port ${addr.port}`);
    console.log(`Inbox directory: ${inboxDir}`);
    console.log(`Device: ${identity.name} (${identity.deviceId})`);
    discovery = startDiscovery({ port: addr.port, name: identity.name, deviceId: identity.deviceId });
    discovery.on('error', (err) => console.error(`uncloud: discovery error: ${err.message}`));
    console.log('Announcing on the LAN via UDP multicast. Press Ctrl+C to stop.');
  });

  process.on('SIGINT', () => {
    console.log('\nShutting down...');
    discovery?.stop();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(0), 500).unref();
  });

  await new Promise(() => {}); // Keep the process alive.
}

async function cmdSend(args) {
  const { values, positionals } = parseCommandArgs(
    args,
    { to: { type: 'string' } },
    'Usage: uncloud send <file> --to <host:port>',
  );
  const file = positionals[0];
  if (!file) {
    printError('missing <file>\nUsage: uncloud send <file> --to <host:port>');
    process.exit(2);
  }
  if (!values.to) {
    printError('missing --to <host:port>\nUsage: uncloud send <file> --to <host:port>');
    process.exit(2);
  }
  const idx = values.to.lastIndexOf(':');
  if (idx <= 0 || idx === values.to.length - 1) {
    printError(`invalid --to "${values.to}", expected host:port`);
    process.exit(2);
  }
  const host = values.to.slice(0, idx);
  const port = parseIntOption(values.to.slice(idx + 1), 'to port');

  const filePath = path.resolve(file);
  if (!fs.existsSync(filePath)) {
    printError(`file not found: ${filePath}`);
    process.exit(1);
  }

  process.stderr.write('Hashing file...\n');
  try {
    const result = await sendFile({
      host,
      port,
      filePath,
      onProgress: ({ sent, total }) => progressBar(sent, total),
    });
    process.stderr.write('\n');
    if (result.reply.ok) {
      console.log(`Sent ${result.file.name} (${formatBytes(result.file.size)}) to ${host}:${port}`);
      console.log(`sha256: ${result.file.sha256}`);
      recordInIndex({
        name: result.file.name,
        size: result.file.size,
        sha256: result.file.sha256,
        peerDeviceId: values.to,
        direction: 'sent',
      });
    } else {
      printError(`receiver rejected the file: ${result.reply.reason ?? 'unknown reason'}`);
      process.exit(1);
    }
  } catch (err) {
    process.stderr.write('\n');
    printError(err.message);
    process.exit(1);
  }
}
/**
 * Self-contained loopback demo:
 * starts a receiver server in-process on 127.0.0.1, sends a random temp file,
 * verifies the hash match, prints success, and cleans everything up.
 */
async function cmdDemo() {
  console.log('=== uncloud loopback demo (127.0.0.1, in-process) ===');

  const demoDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'uncloud-demo-'));
  const inboxDir = path.join(demoDir, 'inbox');
  const filePath = path.join(demoDir, 'demo-photo.bin');
  const data = crypto.randomBytes(1024 * 1024); // 1 MB of random data
  await fsp.writeFile(filePath, data);
  const expectedSha = crypto.createHash('sha256').update(data).digest('hex');

  let server = null;
  try {
    server = startServer({ port: 0, host: '127.0.0.1', inboxDir });
    await new Promise((resolve, reject) => {
      server.once('error', reject);
      server.once('listening', resolve);
    });
    const { port } = server.address();
    console.log(`1. Receiver server listening on 127.0.0.1:${port}, inbox: ${inboxDir}`);
    console.log(`2. Sending demo-photo.bin (${formatBytes(data.length)}) sha256=${expectedSha.slice(0, 16)}...`);

    const result = await sendFile({
      host: '127.0.0.1',
      port,
      filePath,
      onProgress: ({ sent, total }) => progressBar(sent, total),
    });
    process.stderr.write('\n');

    if (!result.reply.ok) {
      throw new Error(`receiver rejected the file: ${result.reply.reason ?? 'unknown reason'}`);
    }
    console.log('3. Receiver replied ok: true');

    const receivedPath = path.join(inboxDir, 'demo-photo.bin');
    const receivedData = await fsp.readFile(receivedPath);
    const actualSha = crypto.createHash('sha256').update(receivedData).digest('hex');
    if (actualSha !== expectedSha) {
      throw new Error(`hash mismatch: expected ${expectedSha}, got ${actualSha}`);
    }
    console.log(`4. Hash verified: ${actualSha.slice(0, 16)}... matches the original file.`);
    console.log('\nDEMO SUCCESS — loopback transfer completed and verified.');
  } catch (err) {
    console.error(`\nDEMO FAILED: ${err.message}`);
    process.exitCode = 1;
  } finally {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    await fsp.rm(demoDir, { recursive: true, force: true });
    console.log('5. Cleaned up demo server and temp files.');
  }
}

/* ------------------------------------------------------------------ */
/* Entry point                                                        */
/* ------------------------------------------------------------------ */

const COMMANDS = {
  id: { run: cmdId },
  scan: { run: cmdScan },
  pair: { run: cmdPair },
  serve: { run: cmdServe },
  send: { run: cmdSend },
  demo: { run: cmdDemo },
};

async function main() {
  const [command, ...rest] = process.argv.slice(2);

  if (!command || command === 'help' || command === '--help' || command === '-h') {
    process.stdout.write(HELP);
    if (!command) process.exitCode = 2;
    return;
  }

  const entry = COMMANDS[command];
  if (!entry) {
    console.error(`uncloud: unknown command: ${command}\n`);
    process.stdout.write(HELP);
    process.exitCode = 2;
    return;
  }

  await entry.run(rest);
}

main().catch((err) => {
  printError(err.message);
  process.exitCode = 1;
});
