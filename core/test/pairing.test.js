import { test } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

import { encodePairingPayload, decodePairingPayload, PAIRING_PREFIX } from '../src/pairing.js';

function sampleInfo() {
  const { publicKey } = crypto.generateKeyPairSync('ed25519');
  return {
    deviceId: '0123456789abcdef',
    name: "Alice's PC",
    host: '192.168.1.42',
    port: 47778,
    publicKeyDer: publicKey.export({ type: 'spki', format: 'der' }),
  };
}

test('encode/decode round-trip preserves all fields', () => {
  const info = sampleInfo();
  const payload = encodePairingPayload(info);
  assert.ok(payload.startsWith(PAIRING_PREFIX), 'payload must start with uncloud://');

  const decoded = decodePairingPayload(payload);
  assert.equal(decoded.v, 1);
  assert.equal(decoded.deviceId, info.deviceId);
  assert.equal(decoded.name, info.name);
  assert.equal(decoded.host, info.host);
  assert.equal(decoded.port, info.port);
  assert.ok(decoded.publicKeyDer.equals(info.publicKeyDer), 'publicKeyDer must round-trip');
  assert.equal(decoded.pub, info.publicKeyDer.toString('base64url'));
});

test('decode accepts base64url alphabet (- and _) without padding issues', () => {
  // Craft bytes that encode to base64url characters '-' and '_'.
  const info = { ...sampleInfo(), publicKeyDer: Buffer.from([0xfb, 0xff, 0xff, 0xfa]) };
  const payload = encodePairingPayload(info);
  assert.ok(!payload.slice(PAIRING_PREFIX.length).includes('='), 'base64url has no padding');
  const decoded = decodePairingPayload(payload);
  assert.ok(decoded.publicKeyDer.equals(info.publicKeyDer));
});

test('decode rejects payloads without the uncloud:// prefix', () => {
  assert.throws(() => decodePairingPayload('https://example.com/abc'), /uncloud:\/\//);
  assert.throws(() => decodePairingPayload(''), /uncloud:\/\//);
  assert.throws(() => decodePairingPayload(null), /uncloud:\/\//);
});

test('decode rejects empty payload body', () => {
  assert.throws(() => decodePairingPayload(PAIRING_PREFIX), /empty/);
});

test('decode rejects non-JSON bodies', () => {
  const bad = PAIRING_PREFIX + Buffer.from('not json at all', 'utf8').toString('base64url');
  assert.throws(() => decodePairingPayload(bad), /base64url/i);
});

test('decode rejects unsupported versions', () => {
  const obj = { v: 99, deviceId: 'x', name: 'x', host: 'x', port: 1, pub: 'eA' };
  const payload = PAIRING_PREFIX + Buffer.from(JSON.stringify(obj)).toString('base64url');
  assert.throws(() => decodePairingPayload(payload), /version/i);
});

test('decode rejects payloads with missing or invalid fields', () => {
  const cases = [
    [{ v: 1, name: 'n', host: 'h', port: 1, pub: 'eA' }, /deviceId/],
    [{ v: 1, deviceId: 'd', host: 'h', port: 1, pub: 'eA' }, /name/],
    [{ v: 1, deviceId: 'd', name: 'n', port: 1, pub: 'eA' }, /host/],
    [{ v: 1, deviceId: 'd', name: 'n', host: 'h', port: 0, pub: 'eA' }, /port/],
    [{ v: 1, deviceId: 'd', name: 'n', host: 'h', port: 70000, pub: 'eA' }, /port/],
    [{ v: 1, deviceId: 'd', name: 'n', host: 'h', port: 1 }, /pub/],
  ];
  for (const [obj, re] of cases) {
    const payload = PAIRING_PREFIX + Buffer.from(JSON.stringify(obj)).toString('base64url');
    assert.throws(() => decodePairingPayload(payload), re, JSON.stringify(obj));
  }
});

test('encode validates its input', () => {
  const info = sampleInfo();
  assert.throws(() => encodePairingPayload({ ...info, deviceId: '' }), /deviceId/);
  assert.throws(() => encodePairingPayload({ ...info, name: '' }), /name/);
  assert.throws(() => encodePairingPayload({ ...info, host: '' }), /host/);
  assert.throws(() => encodePairingPayload({ ...info, port: 0 }), /port/);
  assert.throws(() => encodePairingPayload({ ...info, port: 1.5 }), /port/);
  assert.throws(() => encodePairingPayload({ ...info, publicKeyDer: Buffer.alloc(0) }), /publicKeyDer/);
});
