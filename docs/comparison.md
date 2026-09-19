# How Uncloud compares

An honest comparison. Every tool below is good at something — the goal here is to help you pick the right one, not to declare a winner.

## Quick matrix

|                          | Uncloud | immich | PhotoPrism | Syncthing | LocalSend | Google Photos |
| ------------------------ | :-----: | :----: | :--------: | :-------: | :-------: | :-----------: |
| No server needed         |   ✅    |   ❌¹   |     ❌     |    ✅     |    ✅     |      ❌       |
| No account required      |   ✅    |   ✅   |     ✅     |    ✅     |    ✅     |      ❌       |
| Gallery UX (timeline/map)|   ✅    |   ✅   |     ✅     |    ❌     |    ❌     |      ✅       |
| General file manager     |   ✅    |   ❌   |     ❌     |    ✅     |    ✅     |      ❌       |
| End-to-end encrypted     |   ✅²   |   ❌³   |     ❌     |    ✅     |    ✅     |      ❌       |
| 100% free                |   ✅    |   ✅   |     ✅     |    ✅     |    ✅     |      ❌       |

¹ immich requires a self-hosted server (Docker). ² Wire encryption ships in v0.2; device identity and SHA-256 integrity verification are in place today. ³ immich encrypts traffic in transit only if you configure TLS / a reverse proxy yourself.

## immich

**Strengths:** The best self-hosted Google Photos replacement, full stop. Beautiful timeline, machine-learning search, multi-user support, mobile apps with background backup, extremely active development.

**Where it's a better fit:** You already run (or want to run) a home server or NAS, want multi-user family sharing, or need its ML search *today*.

**Where Uncloud fits:** immich's server *is* the product — Docker containers, a Postgres database, object storage, and the operational duty of backing all that up. Uncloud is for people who want the outcome (photos safe on my PC, browsable as a gallery) without becoming a sysadmin: install an app, scan a QR, done.

## PhotoPrism

**Strengths:** Powerful AI classification, superb metadata/RAW support, mature web UI. A photographer's tool.

**Where it's a better fit:** You have a large, carefully curated library (RAW files, metadata workflows) and a machine to run it on.

**Where Uncloud fits:** PhotoPrism is server software you browse *through*; Uncloud keeps your files as ordinary folders on your PC and adds the gallery on top. PhotoPrism is also not a file manager — it handles photos and videos, not documents, APKs, or the random ZIP you need on your phone.

## Syncthing

**Strengths:** Battle-tested, genuinely peer-to-peer continuous sync, encrypted on the wire, works on almost everything. If you need folders mirrored between five machines, use Syncthing.

**Where it's a better fit:** Continuous folder synchronization across many devices, power users comfortable with folder shares and conflict resolution.

**Where Uncloud fits:** Syncthing deliberately has no gallery — photos arrive as files in folders and stay that way. Uncloud adds the photo-product layer (timeline, map, auto camera-roll backup, pairing via QR instead of device-ID exchange) on top of a much simpler mental model: two devices, one relationship.

## LocalSend

**Strengths:** The gold standard for ad-hoc AirDrop-style sharing. Open source, encrypted, dead simple, huge platform support. For "beam this file to that laptop right now", nothing beats it.

**Where it's a better fit:** One-off transfers between arbitrary devices, including devices you don't own and will never pair with.

**Where Uncloud fits:** LocalSend is stateless by design — no memory of what was sent, no backup, no gallery. Uncloud is the persistent counterpart: paired devices, automatic camera-roll backup, an index of everything transferred, and a place to *browse* your memories afterwards. They complement each other well.

## Google Photos (and cloud photo services generally)

**Strengths:** Zero setup, unlimited-ish convenience, best-in-class search, sharing that "just works" with anyone.

**Where it's a better fit:** You value convenience over data custody, need to share albums with people outside your home, or want off-site disaster protection.

**Where Uncloud fits:** Cloud services require an account, upload your entire library to a third party, and charge rent that scales with your memories. Uncloud's answer: your photos never leave devices you own, there's nothing to subscribe to, and "the service" can never shut down, change its terms, or be breached — because there is no service. The trade-off is real and we state it plainly: Uncloud syncs when your devices share a network, and it is not an off-site backup.

## Positioning statement

> **Uncloud is the photo & file manager for people who want immich's gallery without immich's server, Syncthing's privacy without its folder plumbing, and LocalSend's simplicity as a permanent relationship instead of a one-shot.** It targets the no-server majority: two devices you already own, one QR code, and everything stays yours.
