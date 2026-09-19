/**
 * indexdb.js — simple JSON-file metadata store for received/sent files.
 *
 * Record shape:
 *   { name, size, sha256, peerDeviceId, direction: 'sent'|'received', timestamp }
 */
import fs from 'node:fs';
import path from 'node:path';

const VALID_DIRECTIONS = new Set(['sent', 'received']);

export class IndexDB {
  /**
   * @param {string} filePath Path of the JSON index file (created on first save).
   */
  constructor(filePath) {
    if (!filePath || typeof filePath !== 'string') {
      throw new Error('IndexDB: a file path is required');
    }
    this.path = filePath;
    /** @type {Array<object>} */
    this.records = [];
    this.load();
  }

  /** Load records from disk. Missing or corrupt files start empty (corrupt
   *  files are backed up to *.bak). */
  load() {
    let data = null;
    try {
      data = JSON.parse(fs.readFileSync(this.path, 'utf8'));
    } catch (err) {
      if (err.code !== 'ENOENT') {
        try {
          fs.renameSync(this.path, this.path + '.bak');
        } catch {
          /* best effort */
        }
      }
      this.records = [];
      return;
    }
    this.records = Array.isArray(data?.records) ? data.records : [];
  }

  /** Persist records atomically (write to a temp file, then rename). */
  save() {
    fs.mkdirSync(path.dirname(this.path), { recursive: true });
    const tmp = `${this.path}.tmp-${process.pid}`;
    fs.writeFileSync(tmp, JSON.stringify({ records: this.records }, null, 2));
    fs.renameSync(tmp, this.path);
  }

  /**
   * Add a record and persist the index.
   * @param {object} record
   * @param {string} record.name
   * @param {number} record.size
   * @param {string} [record.sha256]
   * @param {string} [record.peerDeviceId]
   * @param {'sent'|'received'} record.direction
   * @param {string} [record.timestamp] ISO string (defaults to now).
   * @returns {object} the stored record.
   */
  add(record) {
    if (!record || typeof record.name !== 'string' || record.name.length === 0) {
      throw new Error('IndexDB.add: record.name must be a non-empty string');
    }
    if (!Number.isSafeInteger(record.size) || record.size < 0) {
      throw new Error('IndexDB.add: record.size must be a non-negative integer');
    }
    if (!VALID_DIRECTIONS.has(record.direction)) {
      throw new Error('IndexDB.add: record.direction must be "sent" or "received"');
    }
    const stored = {
      name: record.name,
      size: record.size,
      sha256: typeof record.sha256 === 'string' ? record.sha256 : null,
      peerDeviceId: typeof record.peerDeviceId === 'string' ? record.peerDeviceId : null,
      direction: record.direction,
      timestamp: record.timestamp ?? new Date().toISOString(),
    };
    this.records.push(stored);
    this.save();
    return stored;
  }

  /**
   * List records, optionally filtered.
   * @param {object} [filter] e.g. { direction: 'sent', peerDeviceId: 'abc123' }
   * @returns {Array<object>} a shallow copy of matching records.
   */
  list(filter = {}) {
    return this.records.filter((r) => {
      if (filter.direction && r.direction !== filter.direction) return false;
      if (filter.peerDeviceId && r.peerDeviceId !== filter.peerDeviceId) return false;
      if (filter.sha256 && r.sha256 !== filter.sha256) return false;
      return true;
    });
  }

  /** Aggregate statistics over all records. */
  stats() {
    let sent = 0;
    let received = 0;
    let sentBytes = 0;
    let receivedBytes = 0;
    for (const r of this.records) {
      if (r.direction === 'sent') {
        sent++;
        sentBytes += r.size;
      } else if (r.direction === 'received') {
        received++;
        receivedBytes += r.size;
      }
    }
    return {
      total: this.records.length,
      sent,
      received,
      totalBytes: sentBytes + receivedBytes,
      sentBytes,
      receivedBytes,
    };
  }
}
