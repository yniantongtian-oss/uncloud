import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const cli = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'bin', 'uncloud.js');

function run(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [cli, ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { err += d; });
    child.on('error', reject);
    child.on('close', (code) => resolve({ code, out, err }));
  });
}

test('pair --json prints a decodable payload', async () => {
  const { code, out } = await run(['pair', '--json', '--port', '47778']);
  assert.equal(code, 0);
  const obj = JSON.parse(out);
  assert.equal(typeof obj.payload, 'string');
  assert.match(obj.payload, /^uncloud:\/\//);
  assert.equal(obj.port, 47778);
  assert.ok(obj.deviceId);
  assert.ok(obj.host);
});

test('scan --json prints a JSON array', async () => {
  const { code, out } = await run(['scan', '--json', '--timeout', '200']);
  assert.equal(code, 0);
  const obj = JSON.parse(out);
  assert.ok(Array.isArray(obj));
});
