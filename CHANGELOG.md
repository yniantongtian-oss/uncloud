# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
