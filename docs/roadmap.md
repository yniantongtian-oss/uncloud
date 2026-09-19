# Roadmap

Uncloud ships in small, usable increments. Each version below is a checklist; items move to [CHANGELOG.md](../CHANGELOG.md) when released.

## v0.1 — Core CLI + app demo ✅

*Prove the protocol end-to-end with zero dependencies.*

- [x] ed25519 device identity (`uncloud id`), `deviceId` = sha256(SPKI DER) hex prefix
- [x] UDP multicast discovery @ `239.255.77.77:47777` (`uncloud scan`)
- [x] QR pairing payloads `uncloud://` + base64url JSON (`uncloud pair`)
- [x] TCP transfer: JSON header + 64 KB chunks + SHA-256 verification (`uncloud serve` / `send`)
- [x] Local JSON metadata index
- [x] One-command protocol walkthrough (`uncloud demo`)
- [x] Flutter app shell: Android / Windows / macOS / Linux, EN + 中文 UI
- [x] Docs, CI, and repo governance

## v0.2 — Trust the wire, back up the camera roll

*Turn the demo into something you'd actually run daily.*

- [ ] E2E encryption: X25519 key exchange (signed by ed25519 identity) + ChaCha20-Poly1305 records — see [protocol.md §7](protocol.md)
- [ ] Automatic photo backup: watch the camera roll, sync new items when both devices are on the LAN
- [ ] Resume interrupted transfers (offset in header, append on retry)
- [ ] Android release build (APK on GitHub Releases)
- [ ] In-app pairing flow (scan QR → trust → first backup) with zero CLI required
- [ ] Transfer history view in the app

## v0.3 — Make it a gallery

*Your files are on your PC; now make them a joy to browse.*

- [ ] Local AI dedupe: perceptual hashing, on-device, no uploads
- [ ] Local semantic search over the index
- [ ] Face grouping (on-device, opt-in)
- [ ] Map view from EXIF GPS
- [ ] Migrate index from JSON to SQLite (`node:sqlite`) with automatic import
- [ ] Timeline performance pass (thumbnail cache, lazy decoding)

## v1.0 — For everyone

- [ ] iOS app (pairing, backup, gallery within platform background limits)
- [ ] Distribution: Google Play / F-Droid, Microsoft Store / winget, Homebrew
- [ ] Localization beyond EN/中文 driven by community contributions
- [ ] Stable protocol `v` freeze with conformance tests
- [ ] Security review of the encryption layer

## How priorities are chosen

1. **North star first** — anything that weakens "no cloud, no account, no server" is a non-goal, however popular.
2. **Trust before features** — encryption (v0.2) ships before AI (v0.3), deliberately.
3. **Issues and discussions** — vote with 👍 on issues; the roadmap is revisited each release.

Want to move something up the list? [Open an issue](https://github.com/yniantongtian-oss/uncloud/issues) or pick up a checklist item — see [CONTRIBUTING.md](../CONTRIBUTING.md).
