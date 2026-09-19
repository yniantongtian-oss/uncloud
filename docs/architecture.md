# Uncloud Architecture

This document explains how Uncloud is structured and — just as importantly — *why* it is built this way.

> **North star: No cloud. No account. No server.** Every architectural decision below is judged against it.

## Layers

```
┌─────────────────────────────────────────────────────────┐
│  App / UI layer            (app/, Flutter)              │
│  Timeline · map view · file browser · EN/中文 i18n      │
├─────────────────────────────────────────────────────────┤
│  Services layer            (app/lib/services)           │
│  Scan device media · watch folders · schedule backup    │
│  Talk to the engine: discovery, pairing, transfer       │
├─────────────────────────────────────────────────────────┤
│  Core engine               (core/, zero-dep Node.js)    │
│  id → ed25519 identity · scan → discovery · pair → QR   │
│  serve → TCP receiver · send → TCP sender               │
│  Local JSON metadata index                              │
├─────────────────────────────────────────────────────────┤
│  Protocol layer            (docs/protocol.md)           │
│  UDP multicast discovery · QR pairing handshake         │
│  TCP transfer: JSON header + 64 KB chunks + sha256      │
└─────────────────────────────────────────────────────────┘
```

Data flows **down** the stack only (UI → services → engine → protocol); results and events flow back up. The protocol layer is the contract: any conforming implementation — CLI, app, or third-party tool — can interoperate.

## Module map

| Module | Lives in | Responsibility |
| ------ | -------- | -------------- |
| `bin/uncloud.js` | `core/` | CLI entry: `id`, `scan`, `pair`, `serve`, `send`, `demo` |
| Identity | `core/` | Generate/load ed25519 keypair; derive `deviceId` |
| Discovery | `core/` | UDP multicast announce (2 s) and peer table (8 s expiry) |
| Pairing | `core/` | Encode/decode `uncloud://` QR payloads; persist trusted peers |
| Transfer | `core/` | TCP server/client; stream files in 64 KB chunks; verify SHA-256 |
| Index | `core/` | JSON metadata store of received/sent files |
| Media service | `app/` | Enumerate camera roll & files, compute hashes, queue uploads |
| Gallery | `app/` | Timeline / map / folder views over the local index |
| i18n | `app/` | English default, Simplified Chinese switch |

## Key decisions, and why

### Why a zero-dependency Node.js core?

- **Zero dependencies means zero supply-chain risk.** For software whose entire promise is "trust no third party", pulling in hundreds of npm packages would be self-defeating. Everything Uncloud needs — `crypto`, `dgram`, `net`, `fs` — ships with Node itself.
- **Runs everywhere the PC does.** Windows, macOS, Linux with a single runtime and no native build step.
- **Auditable.** The whole engine can be read in an afternoon. That's a security feature.
- **`demo` as a teaching tool.** `node bin/uncloud.js demo` exercises identity → discovery → pairing → transfer end-to-end, making the protocol observable without any app.

### Why Flutter for the app?

- **One codebase, five targets.** Android, iOS, Windows, macOS, Linux — which is exactly Uncloud's platform matrix.
- **First-class gallery UX.** Smooth grid scrolling, gestures, and map integration are table stakes in Flutter; a CLI-quality UI would not be.
- **Platform channels where needed.** Media-library access and background tasks use each OS's native APIs behind a thin Dart interface, keeping the cross-platform core clean.

### Why a JSON index first, SQLite later?

- **v0.1 optimizes for correctness and readability**, not query performance. A JSON file is diff-able, hand-editable, and trivially recoverable.
- The index is small by design: it stores *metadata* (name, size, sha256, timestamps, peer), never the files themselves — those live as ordinary files in ordinary folders.
- **SQLite lands in v0.3** (via `node:sqlite`) once queries get real — full-text search, dedupe, map clustering — without changing the storage contract the app already depends on.

## Security model

- **Device identity.** Each device generates an ed25519 keypair locally (`node:crypto`). The `deviceId` is the first 16 hex characters of `sha256(SPKI DER)` of the public key — short enough to display, collision-safe enough for a LAN. Private keys never leave the device and are stored with owner-only permissions.
- **Pairing is the trust root.** Scanning a QR code transfers the peer's `deviceId` and public key *in person*, giving us trust-on-first-use with a physical ceremony. After pairing, a device only accepts connections from known peers; unpaired announcements are ignored for transfer.
- **Integrity today, confidentiality next.** Every transfer is verified end-to-end with SHA-256 by the receiver before it replies `{ok:true}`. v0.2 adds X25519 key exchange + ChaCha20-Poly1305 so LAN eavesdroppers see only ciphertext (see [protocol.md §7](protocol.md)).
- **Path sanitization.** Incoming filenames are stripped of directory components (`/`, `\`, `..`, drive letters) and collisions are renamed, never overwritten silently. The receiver writes only inside its designated inbox directory — a malicious or buggy peer cannot scribble elsewhere on disk.
- **No network egress.** Uncloud opens no outbound internet connections. Discovery is multicast-only; transfers are LAN TCP only.

See [protocol.md](protocol.md) for the exact wire formats and [roadmap.md](roadmap.md) for when each security milestone ships.
