import { test } from 'node:test';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import net from 'node:net';
import crypto from 'node:crypto';

import { startServer, sendFile, sanitizeFileName } from '../src/transfer.js';

function sha256(data) {
  return crypto.createHash('sha256').update(data).digest('hex');
}

/** Start a loopback server on an ephemeral port; returns a helper object. */
async function makeServer(t) {
  const dir = await fsp.mkdtemp(path.join(os.tmpdir(), 'uncloud-xfer-'));
  const inboxDir = path.join(dir, 'inbox');
  const received = [];
  const server = startServer({
    port: 0,
    host: '127.0.0.1',
    inboxDir,
    onFileReceived: (record) => received.push(record),
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.once('listening', resolve);
  });
  t.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await fsp.rm(dir, { recursive: true, force: true });
  });
  return { server, dir, inboxDir, received, port: server.address().port };
}

test('loopback transfer of a random 1 MB file verifies sha256', async (t) => {
  const ctx = await makeServer(t);

  const data = crypto.randomBytes(1024 * 1024);
  const filePath = path.join(ctx.dir, 'photo-1mb.bin');
  await fsp.writeFile(filePath, data);

  const progressEvents = [];
  const result = await sendFile({
    host: '127.0.0.1',
    port: ctx.port,
    filePath,
    onProgress: (p) => progressEvents.push(p),
  });

  assert.deepEqual(result.reply, { ok: true });
  assert.equal(result.file.sha256, sha256(data));
  assert.ok(progressEvents.length > 0, 'progress must be reported');
  assert.equal(progressEvents.at(-1).sent, data.length);

  const receivedPath = path.join(ctx.inboxDir, 'photo-1mb.bin');
  const receivedData = await fsp.readFile(receivedPath);
  assert.equal(sha256(receivedData), sha256(data), 'received file hash must match');
  assert.equal(receivedData.length, data.length);

  assert.equal(ctx.received.length, 1);
  assert.equal(ctx.received[0].name, 'photo-1mb.bin');
  assert.equal(ctx.received[0].size, data.length);
  assert.equal(ctx.received[0].direction, 'received');
});

test('tampered header hash makes the receiver reply ok:false', async (t) => {
  const ctx = await makeServer(t);

  const data = crypto.randomBytes(256 * 1024);
  const fakeHash = sha256(Buffer.from('this is not the real content'));

  // Manual protocol client: send a header with a deliberately wrong hash.
  const reply = await new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: '127.0.0.1', port: ctx.port });
    let buf = '';
    socket.on('error', reject);
    socket.on('connect', () => {
      socket.write(JSON.stringify({ name: 'tampered.bin', size: data.length, sha256: fakeHash }) + '\n');
      socket.write(data);
    });
    socket.on('data', (chunk) => {
      buf += chunk.toString('utf8');
      const nl = buf.indexOf('\n');
      if (nl !== -1) {
        socket.end();
        resolve(JSON.parse(buf.slice(0, nl)));
      }
    });
  });

  assert.equal(reply.ok, false);
  assert.match(reply.reason, /hash mismatch/i);
  assert.equal(ctx.received.length, 0, 'rejected files must not be recorded');
  // The partial file must have been deleted.
  const leftovers = fs.existsSync(ctx.inboxDir) ? await fsp.readdir(ctx.inboxDir) : [];
  assert.deepEqual(leftovers, []);
});
test('sendFile reports a clear error when the file does not exist', async (t) => {
  const ctx = await makeServer(t);
  await assert.rejects(
    sendFile({ host: '127.0.0.1', port: ctx.port, filePath: path.join(ctx.dir, 'missing.bin') }),
    /File not found/,
  );
});

test('sendFile reports connection refused with a friendly message', async (t) => {
  await makeServer(t);
  // Grab an ephemeral port and immediately close the socket holding it, so
  // the port is (almost certainly) free and refuses connections.
  const probe = net.createServer();
  await new Promise((resolve) => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port;
  await new Promise((resolve) => probe.close(resolve));

  const tmp = await fsp.mkdtemp(path.join(os.tmpdir(), 'uncloud-refused-'));
  t.after(() => fsp.rm(tmp, { recursive: true, force: true }));
  const filePath = path.join(tmp, 'f.bin');
  await fsp.writeFile(filePath, 'hello');

  await assert.rejects(sendFile({ host: '127.0.0.1', port, filePath }), /refused/i);
});

test('sanitizeFileName blocks path traversal and illegal characters', () => {
  assert.equal(sanitizeFileName('../../etc/passwd'), 'passwd');
  assert.equal(sanitizeFileName('..\\..\\win\\system32\\evil.dll'), 'evil.dll');
  assert.notEqual(sanitizeFileName('..'), '..');
  assert.notEqual(sanitizeFileName('.'), '.');
  assert.match(sanitizeFileName('..'), /^unnamed-\d+$/);
  assert.equal(sanitizeFileName('a<b>c:d"e|f?g*h.jpg'), 'a_b_c_d_e_f_g_h.jpg');
  assert.equal(sanitizeFileName('normal photo (2).jpg'), 'normal photo (2).jpg');
  // Sanitized names must never escape the inbox.
  const inbox = path.resolve('some-inbox');
  for (const nasty of ['../../x', '..\\..\\y', '..', '.', 'a/b/c']) {
    const dest = path.join(inbox, sanitizeFileName(nasty));
    assert.ok(dest.startsWith(inbox + path.sep), `${nasty} escaped the inbox: ${dest}`);
  }
});

test('server handles multiple sequential connections', async (t) => {
  const ctx = await makeServer(t);
  for (let i = 0; i < 3; i++) {
    const filePath = path.join(ctx.dir, `seq-${i}.txt`);
    await fsp.writeFile(filePath, `sequential file number ${i}`);
    const result = await sendFile({ host: '127.0.0.1', port: ctx.port, filePath });
    assert.deepEqual(result.reply, { ok: true });
  }
  assert.equal(ctx.received.length, 3);
  const names = (await fsp.readdir(ctx.inboxDir)).sort();
  assert.deepEqual(names, ['seq-0.txt', 'seq-1.txt', 'seq-2.txt']);
});

test('zero-byte file transfers and verifies (empty sha256)', async (t) => {
  const ctx = await makeServer(t);
  const filePath = path.join(ctx.dir, 'empty.bin');
  await fsp.writeFile(filePath, Buffer.alloc(0));
  const result = await sendFile({ host: '127.0.0.1', port: ctx.port, filePath });
  assert.deepEqual(result.reply, { ok: true });
  assert.equal(result.file.sha256, sha256(Buffer.alloc(0)));
  const receivedData = await fsp.readFile(path.join(ctx.inboxDir, 'empty.bin'));
  assert.equal(receivedData.length, 0);
});

test('duplicate names get a unique destination instead of overwriting', async (t) => {
  const ctx = await makeServer(t);
  const filePath = path.join(ctx.dir, 'dup.txt');
  await fsp.writeFile(filePath, 'same name, sent twice');
  await sendFile({ host: '127.0.0.1', port: ctx.port, filePath });
  await sendFile({ host: '127.0.0.1', port: ctx.port, filePath });
  const names = (await fsp.readdir(ctx.inboxDir)).sort();
  assert.deepEqual(names, ['dup (1).txt', 'dup.txt']);
});
