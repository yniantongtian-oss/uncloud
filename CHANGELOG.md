# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Local-first sync planner: a JSON library on device, skip files a paired peer already has by SHA-256, and resume from the last acknowledged byte.
- On-device duplicate assistant: exact SHA-256 groups and difference-hash lookalikes. Distance is a fixed 64-bit count, so a hash with the high bit set cannot spin. Face grouping is unchanged.
- Unit and widget tests for pairing validation, the peer table, transfers, the sync planner, and the backup / duplicate flows.

### Fixed

- Pairing rejects unsupported payload versions, ports outside 1–65535, and a `deviceId` that does not match `sha256` of the SPKI public key.
- A corrupt paired-device record no longer crashes startup.
- Peers that leave the latest scan drop off the discovered list. A later announce cannot undo unpair or wipe stored storage numbers.
- The backup target is the paired device seen most recently.
- Cancelling a transfer stays cancelled if the transport later reports success. "Clear completed" no longer deletes failed transfers.
- The queue runs oldest-first. Transfer speed is 0 B/s when progress rewinds instead of a negative rate.
- "Backup now" sends the library gap for that device instead of phantom `IMG_backup_*.jpg` names. The CLI transport refuses a send that has no `host:port` and file path.
- Discovery and pairing CLI calls tolerate malformed JSON instead of surfacing an uncaught error.
- Flutter `pub get` on current stable: `intl` is `>=0.20.3 <0.21.0` so it matches `flutter_localizations`.
- Desktop CLI transport now calls `uncloud send <file> --to host:port` (the real CLI), and queues include the peer LAN address.
- `core/package.json` license field now matches the Apache-2.0 `LICENSE` file.
- Markdown lint config so README HTML/screenshots are allowed; CI markdown job is no longer a wall of false positives.

### Changed

- CI runs `flutter analyze --fatal-infos`. The app enables strict casts, inference, and raw types, plus a stricter lint set.
- Direct dependency on `package:crypto` for SHA-256 device ids and picked-file hashes. SDK constraint is `>=3.10.0 <4.0.0` (file_picker 13).
- README feature list matches v0.1: auto backup / map / local AI are labeled as upcoming.
- Desktop app talks to the Node core when `core/bin/uncloud.js` is present: LAN scan, pairing QR from the real identity, file send via CLI, and a background `uncloud serve` receiver into Documents/Uncloud.
- Flutter Android / Windows / web platform folders generated so the app can actually be built.
- Pairing accepts the core `uncloud://` + base64url JSON payload (CLI QR) as well as the older query-string form.

## [0.1.0] — Initial release

### Added

- **Core engine** (zero-dependency Node.js, `core/`):
  - CLI entry point `bin/uncloud.js` with commands: `id`, `scan`, `pair`, `serve`, `send`, `demo`.
  - Device identity: ed25519 keypair via `node:crypto`; `deviceId` = first 16 hex chars of `sha256(SPKI DER)`.
  - LAN discovery over UDP multicast `239.255.77.77:47777` (announce every 2 s, peer expiry after 8 s).
  - QR pairing payloads: `uncloud://` + base64url JSON (`{v, deviceId, name, host, port, pub}`).
  - TCP file transfer: one-line JSON header `{name, size, sha256}` followed by raw 64 KB chunks, with receiver-side SHA-256 verification and `{ok}` reply.
  - Local JSON metadata index — all data stays on the user's devices.
- **App** (`app/`): Flutter shell for Android / iOS / Windows / macOS / Linux, English UI by default with Simplified Chinese switch.
- **Docs & governance**: English and Simplified Chinese READMEs, `docs/` (architecture, protocol, comparison, roadmap), CONTRIBUTING, CODE_OF_CONDUCT, Apache-2.0 LICENSE, CI workflow, issue & PR templates.

[Unreleased]: https://github.com/yniantongtian-oss/uncloud/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yniantongtian-oss/uncloud/releases/tag/v0.1.0
