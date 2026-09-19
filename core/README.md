# Uncloud Core

Local-first, zero-cloud engine + CLI to manage and sync photos & files between your phone and PC over LAN. **Node.js standard library only — zero npm dependencies.** Requires Node.js v20+ (developed/tested on v24).

```
uncloud-core/
├── package.json
├── bin/uncloud.js        # CLI entry point
├── src/
│   ├── identity.js       # ed25519 keypair identity (~/.uncloud/identity.json)
│   ├── discovery.js      # UDP multicast peer discovery (239.255.77.77:47777)
│   ├── pairing.js        # uncloud:// pairing payload encode/decode (for QR codes)
│   ├── transfer.js       # TCP file transfer with sha256 verification
│   └── indexdb.js        # JSON-file metadata index of sent/received files
└── test/                 # node:test test suite (30 tests)
```

## Quick start

```sh
# Self-contained loopback demo (server + client in one process):
node bin/uncloud.js demo        # or: npm run demo

# Run the test suite:
node --test "test/*.test.js"    # or: npm test
```

> **Windows note:** `node --test test/` (directory argument) fails with `MODULE_NOT_FOUND`
> due to Node.js bug [#64555](https://github.com/nodejs/node/issues/64555) (regression
> since v20, fixed after v24.14.0). On Windows use `node --test "test/*.test.js"` or plain
> `node --test` (auto-discovers the `test/` directory) — both run the full suite.

## CLI usage

### `uncloud id`
Show this device's identity (created on first use at `~/.uncloud/identity.json`):

```sh
$ node bin/uncloud.js id
Name:        DESKTOP-ABC123
Device ID:   9f2c71ab04e58d31
Fingerprint: 9f2c71ab04e58d31...  (sha256 of the spki DER public key)
```

### `uncloud scan [--timeout ms]`
Discover Uncloud peers on the LAN via UDP multicast (default timeout 4000 ms):

```sh
$ node bin/uncloud.js scan --timeout 5000
DEVICE ID         NAME         HOST           PORT
----------------  -----------  -------------  -----
9f2c71ab04e58d31  Alice's PC   192.168.1.42   47778
```

### `uncloud pair [--port 47778]`
Print this device's pairing payload — a compact `uncloud://...` string meant to be rendered as a QR code:

```sh
$ node bin/uncloud.js pair
Pairing payload for "DESKTOP-ABC123" (192.168.1.42:47778):
uncloud://eyJ2IjoxLCJkZXZpY2VJZCI6IjlmMmM3MWFiMDRlNThkMzEiLC...
```

### `uncloud serve [--port 47778] [--dir ./uncloud-inbox]`
Run the receiver server and announce it on the LAN (Ctrl+C to stop):

```sh
$ node bin/uncloud.js serve --port 47778 --dir ./uncloud-inbox
uncloud serve — receiving files on port 47778
Inbox directory: E:\cline\uncloud\core\uncloud-inbox
Announcing on the LAN via UDP multicast. Press Ctrl+C to stop.
[2026-01-01T12:00:00.000Z] received holiday.jpg (2.4 MB) from 192.168.1.77
```

Received files are written to the inbox with path-traversal-safe names (duplicate names become `name (1).ext`), sha256-verified, and logged to `~/.uncloud/index.json`. Files whose hash does not match are deleted and the sender is told `{ok:false}`.

### `uncloud send <file> --to <host:port>`
Send a file to a peer (progress bar on stderr):

```sh
$ node bin/uncloud.js send photo.jpg --to 192.168.1.42:47778
[██████████████████████████████] 100% 2.4 MB/2.4 MB
Sent photo.jpg (2.4 MB) to 192.168.1.42:47778
sha256: 21765fdc1820cdc1...
```

### `uncloud demo`
Self-contained loopback demo on 127.0.0.1: starts the receiver in-process, sends a random 1 MB temp file, verifies the hash, prints `DEMO SUCCESS`, and cleans up.
## Protocol

1. **Identity** — ed25519 keypair (`node:crypto`), PEM in `~/.uncloud/identity.json`. `deviceId` = first 16 hex chars of `sha256(spki DER)`.
2. **Discovery** — UDP multicast `239.255.77.77:47777`; JSON announce every 2 s (`{type:'announce', deviceId, name, port, version:1}`); peers deduped by `deviceId`, expire after 8 s of silence.
3. **Pairing** — `uncloud://` + base64url(JSON `{v:1, deviceId, name, host, port, pub}`) where `pub` is the base64url spki DER public key.
4. **Transfer** — TCP: one header line `{"name","size","sha256"}` + `\n`, then raw bytes in 64 KB chunks. Receiver writes to `<inbox>/<sanitized name>`, hashes while writing, replies one line `{"ok":true}` or `{"ok":false,"reason":"..."}`.
5. **Index** — JSON metadata store of transfers: `{name, size, sha256, peerDeviceId, direction, timestamp}`.

## API

```js
import { loadOrCreateIdentity, getDeviceId, publicKeyDer } from './src/identity.js';
import { startDiscovery } from './src/discovery.js';
import { encodePairingPayload, decodePairingPayload } from './src/pairing.js';
import { startServer, sendFile, sanitizeFileName } from './src/transfer.js';
import { IndexDB } from './src/indexdb.js';

// Identity
const identity = loadOrCreateIdentity();          // { publicKey, privateKey, name, createdAt, deviceId }
const id = getDeviceId(identity);                 // 16 hex chars

// Discovery
const discovery = startDiscovery({ port: 47778, name: identity.name, deviceId: identity.deviceId });
discovery.on('peer', (peer) => console.log('found', peer));
console.log(discovery.peers);                     // snapshot array
discovery.stop();

// Pairing
const payload = encodePairingPayload({
  deviceId: identity.deviceId, name: identity.name,
  host: '192.168.1.42', port: 47778, publicKeyDer: publicKeyDer(identity),
});
const info = decodePairingPayload(payload);       // { v, deviceId, name, host, port, pub, publicKeyDer }

// Transfer
const server = startServer({
  port: 47778, inboxDir: './uncloud-inbox',
  onProgress: ({ received, total, name }) => {},
  onFileReceived: (record) => console.log('got', record.name),
});
server.on('error', (err) => console.error(err));  // e.g. EADDRINUSE

const { reply, file } = await sendFile({
  host: '192.168.1.42', port: 47778, filePath: './photo.jpg',
  onProgress: ({ sent, total }) => {},
});
if (reply.ok) console.log('delivered', file.sha256);
else console.error('rejected:', reply.reason);

// Index
const db = new IndexDB('./index.json');
db.add({ name: 'photo.jpg', size: 1234, sha256: '…', peerDeviceId: '9f2c…', direction: 'received' });
console.log(db.list({ direction: 'received' }), db.stats());
```

## Error handling

- `EADDRINUSE` on serve → clear "port already in use" message, exit code 1.
- Missing file on send → "file not found", exit code 1.
- `ECONNREFUSED` on send → "Connection refused … is the peer running `uncloud serve`?".
- Corrupt `identity.json` / `index.json` → backed up to `*.bak` and recreated empty/fresh.
- Hash mismatch / malformed header / header > 64 KB → receiver replies `{ok:false, reason}` and deletes the partial file.

## License

MIT
