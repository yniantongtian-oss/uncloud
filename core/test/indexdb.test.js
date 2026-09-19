import { test } from 'node:test';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import fs from 'node:fs';

import { IndexDB } from '../src/indexdb.js';

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'uncloud-dbtest-'));
}

test('add/list round-trip and persistence across instances', () => {
  const dir = makeTempDir();
  try {
    const file = path.join(dir, 'index.json');
    const db = new IndexDB(file);
    db.add({ name: 'a.jpg', size: 100, sha256: 'aa', peerDeviceId: 'peer1', direction: 'sent' });
    db.add({ name: 'b.jpg', size: 200, sha256: 'bb', peerDeviceId: 'peer1', direction: 'received' });

    // Fresh instance reads the same file from disk.
    const db2 = new IndexDB(file);
    const all = db2.list();
    assert.equal(all.length, 2);
    assert.equal(all[0].name, 'a.jpg');
    assert.equal(all[0].direction, 'sent');
    assert.equal(all[1].name, 'b.jpg');
    assert.ok(typeof all[0].timestamp === 'string', 'timestamp defaults to now');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('list() filters by direction and peerDeviceId', () => {
  const dir = makeTempDir();
  try {
    const db = new IndexDB(path.join(dir, 'index.json'));
    db.add({ name: 's1', size: 1, direction: 'sent', peerDeviceId: 'phone' });
    db.add({ name: 's2', size: 2, direction: 'sent', peerDeviceId: 'laptop' });
    db.add({ name: 'r1', size: 3, direction: 'received', peerDeviceId: 'phone' });

    assert.equal(db.list({ direction: 'sent' }).length, 2);
    assert.equal(db.list({ direction: 'received' }).length, 1);
    assert.equal(db.list({ peerDeviceId: 'phone' }).length, 2);
    assert.equal(db.list({ direction: 'sent', peerDeviceId: 'laptop' }).length, 1);
    assert.equal(db.list().length, 3);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('stats() aggregates counts and bytes by direction', () => {
  const dir = makeTempDir();
  try {
    const db = new IndexDB(path.join(dir, 'index.json'));
    db.add({ name: 's1', size: 1000, direction: 'sent' });
    db.add({ name: 's2', size: 500, direction: 'sent' });
    db.add({ name: 'r1', size: 2500, direction: 'received' });

    const stats = db.stats();
    assert.equal(stats.total, 3);
    assert.equal(stats.sent, 2);
    assert.equal(stats.received, 1);
    assert.equal(stats.sentBytes, 1500);
    assert.equal(stats.receivedBytes, 2500);
    assert.equal(stats.totalBytes, 4000);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('missing index file starts empty', () => {
  const dir = makeTempDir();
  try {
    const db = new IndexDB(path.join(dir, 'nested', 'index.json'));
    assert.deepEqual(db.list(), []);
    assert.equal(db.stats().total, 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('corrupt index file is backed up and starts empty', () => {
  const dir = makeTempDir();
  try {
    const file = path.join(dir, 'index.json');
    fs.writeFileSync(file, '{broken json', 'utf8');
    const db = new IndexDB(file);
    assert.deepEqual(db.list(), []);
    assert.ok(fs.existsSync(file + '.bak'), 'corrupt file must be backed up');
    // The db stays usable after recovery.
    db.add({ name: 'x', size: 1, direction: 'sent' });
    assert.equal(new IndexDB(file).list().length, 1);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('add() validates records and rejects bad input', () => {
  const dir = makeTempDir();
  try {
    const db = new IndexDB(path.join(dir, 'index.json'));
    assert.throws(() => db.add({ size: 1, direction: 'sent' }), /name/);
    assert.throws(() => db.add({ name: 'x', size: -1, direction: 'sent' }), /size/);
    assert.throws(() => db.add({ name: 'x', size: 1.5, direction: 'sent' }), /size/);
    assert.throws(() => db.add({ name: 'x', size: 1, direction: 'sideways' }), /direction/);
    // Failed adds must not corrupt the stored index.
    assert.equal(db.stats().total, 0);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
