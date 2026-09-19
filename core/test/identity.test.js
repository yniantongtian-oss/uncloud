import { test } from 'node:test';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs';
import crypto from 'node:crypto';

import {
  loadOrCreateIdentity,
  getDeviceId,
  computeDeviceId,
  publicKeyDer,
  sha256Hex,
  identityPath,
} from '../src/identity.js';

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'uncloud-idtest-'));
}

test('creates a new identity with all required fields', () => {
  const dir = makeTempDir();
  try {
    const id = loadOrCreateIdentity({ dir, name: 'test-device' });
    assert.equal(id.name, 'test-device');
    assert.ok(typeof id.publicKey === 'string' && id.publicKey.includes('BEGIN PUBLIC KEY'));
    assert.ok(typeof id.privateKey === 'string' && id.privateKey.includes('BEGIN PRIVATE KEY'));
    assert.ok(!Number.isNaN(Date.parse(id.createdAt)), 'createdAt must be a valid date');
    assert.match(id.deviceId, /^[0-9a-f]{16}$/, 'deviceId must be 16 hex chars');
    assert.ok(fs.existsSync(identityPath(dir)), 'identity.json must be written to disk');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('loads the same identity on second call (persistence)', () => {
  const dir = makeTempDir();
  try {
    const first = loadOrCreateIdentity({ dir, name: 'persistent-device' });
    const second = loadOrCreateIdentity({ dir }); // no name -> must not regenerate
    assert.equal(second.publicKey, first.publicKey);
    assert.equal(second.privateKey, first.privateKey);
    assert.equal(second.name, 'persistent-device');
    assert.equal(second.deviceId, first.deviceId);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('deviceId = first 16 hex chars of sha256(spki DER)', () => {
  const dir = makeTempDir();
  try {
    const id = loadOrCreateIdentity({ dir });
    const der = crypto.createPublicKey(id.publicKey).export({ type: 'spki', format: 'der' });
    const expected = crypto.createHash('sha256').update(der).digest('hex').slice(0, 16);
    assert.equal(id.deviceId, expected);
    assert.equal(getDeviceId(id), expected);
    assert.equal(computeDeviceId(id.publicKey), expected);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('publicKeyDer returns the spki DER bytes', () => {
  const dir = makeTempDir();
  try {
    const id = loadOrCreateIdentity({ dir });
    const der = publicKeyDer(id);
    assert.ok(Buffer.isBuffer(der) && der.length > 0);
    // Round-trip: DER -> key object -> PEM must match.
    const keyObj = crypto.createPublicKey({ key: der, type: 'spki', format: 'der' });
    assert.equal(keyObj.export({ type: 'spki', format: 'pem' }), id.publicKey);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('regenerates identity when the file is corrupt', () => {
  const dir = makeTempDir();
  try {
    fs.writeFileSync(identityPath(dir), 'this is not json', 'utf8');
    const id = loadOrCreateIdentity({ dir, name: 'recovered' });
    assert.equal(id.name, 'recovered');
    assert.ok(fs.existsSync(identityPath(dir) + '.bak'), 'corrupt file must be backed up');
    // Fresh identity is a valid ed25519 key.
    assert.doesNotThrow(() => crypto.createPublicKey(id.publicKey));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('two distinct identities have distinct deviceIds', () => {
  const dirA = makeTempDir();
  const dirB = makeTempDir();
  try {
    const a = loadOrCreateIdentity({ dir: dirA, name: 'A' });
    const b = loadOrCreateIdentity({ dir: dirB, name: 'B' });
    assert.notEqual(a.deviceId, b.deviceId);
  } finally {
    fs.rmSync(dirA, { recursive: true, force: true });
    fs.rmSync(dirB, { recursive: true, force: true });
  }
});

test('sha256Hex produces a lowercase hex digest', () => {
  assert.equal(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});

test('getDeviceId rejects invalid input', () => {
  assert.throws(() => getDeviceId(null), /publicKey/);
  assert.throws(() => getDeviceId({}), /publicKey/);
});
