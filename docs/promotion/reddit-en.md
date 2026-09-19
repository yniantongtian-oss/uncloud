# Reddit / Hacker News Cold-Launch Copy (English)

> Timing: post **after v0.2** (wire encryption + auto-backup) with a real 30-second demo GIF.
> Subreddits: r/selfhosted, r/privacy, r/fossdroid, r/FlutterDev (dev angle), r/DataHoarder.
> HN: "Show HN" — Tuesday–Thursday, 8–10am US Eastern performs best.

---

## Reddit r/selfhosted — title options

1. **Uncloud: an immich-style photo backup that needs NO server — phone and PC pair directly over LAN**
2. **I wanted immich's gallery without running Docker, so I built a serverless, LAN-only alternative**

## Reddit body (r/selfhosted)

---

I love immich. I also know exactly zero non-technical family members who will ever run Docker, a reverse proxy, and TLS certs just to back up their camera roll.

So I built **Uncloud** — same "your photos, your hardware" idea, minus the server:

- **No server, no account, no cloud.** Phone and PC discover each other on your Wi-Fi (UDP multicast), pair once via QR code, then talk directly over TCP.
- **Gallery + file manager in one.** Timeline / map views like a real photo app, plus a cross-device file browser for everything else.
- **Local-only AI (WIP).** Dedupe and face grouping run on-device. Nothing is uploaded for "intelligence".
- **Verifiable.** Every transfer is SHA-256-checked; the whole thing is Apache-2.0.

**Stack:** zero-dependency Node.js core (literally `node bin/uncloud.js demo` runs a loopback transfer with hash verification, no `npm install`), Flutter app for Android/iOS/desktop, ed25519 device identity. Wire encryption (X25519 + ChaCha20-Poly1305) lands in v0.2.

**Where it fits vs. the tools I compared it with:**
- *immich/PhotoPrism* → best if you already run a server. Uncloud is for everyone who doesn't.
- *Syncthing* → rock-solid byte sync, but no gallery UX.
- *LocalSend* → great one-shot courier, but no persistent backup/organization.

GitHub: https://github.com/yniantongtian-oss/uncloud (30 passing tests, real demo, honest roadmap — it's v0.1, not vaporware)

Happy to hear harsh feedback. Two genuine questions: (1) is "both devices on the same LAN" an acceptable trade for "zero cloud"? (2) would you rather see E2E encryption or auto-backup prioritized?

---

## Hacker News — Show HN

**Title:** `Show HN: Uncloud – local-first photo/file sync between phone and PC, no server or cloud`

**First comment (post immediately after submitting):**

> Hi HN! I built Uncloud because every "easy" photo backup option either costs a subscription, runs on someone else's computer, or requires me to be a sysadmin (Docker + NAS + TLS).
>
> How it works: devices find each other via UDP multicast (239.255.77.77:47777), pair once with a QR code containing an ed25519 public key, then stream files over raw TCP in 64 KB chunks with SHA-256 verification. The core engine is zero-dependency Node.js — you can run `node bin/uncloud.js demo` right now and watch a verified loopback transfer with no install step.
>
> The app is Flutter (EN/中文 UI). v0.1 is identity/discovery/pairing/transfer; v0.2 adds X25519+ChaCha20-Poly1305 wire encryption and auto-backup; v0.3 adds on-device AI dedupe/search.
>
> Known limits: same-LAN only (no relay by design), iOS background sync is constrained by the OS. I'd genuinely love feedback on the protocol (docs/protocol.md) and whether the no-server trade-off makes sense to you.

---

## Asset checklist (must attach — no GIF = no traction)

1. 15s GIF: scan QR on phone → PC appears → photo lands on PC timeline
2. Screenshot: timeline view (EN) + settings page showing language switch
3. Terminal screenshot: `node bin/uncloud.js demo` → "DEMO SUCCESS"

## After posting

- Stay in comments for the first 3 hours, reply to everything, convert "does it do X?" into GitHub issues
- Never trash immich — "immich is for people with a NAS; Uncloud is for people without one"
- If r/selfhosted gets >100 upvotes → cross-post r/privacy + r/fossdroid 24h later, submit Show HN
