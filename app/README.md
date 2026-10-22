# Uncloud (app)

> **No cloud. No account. No server.**
> A local-first photo & file manager that syncs between your phone and PC over
> your own LAN.

This is the Flutter front end. It currently ships with a **demo mode**: all
discovery, pairing, timeline and transfer data is simulated in-process so the
app builds and runs standalone with no companion core.

## Features

- **Onboarding** — 3-page intro (privacy / direct link / local AI), shown once.
- **Pairing** — shows this device's `uncloud://pair/...` QR code (via
  `qr_flutter`), a stubbed "scan to pair" flow, and an auto-discovery list
  with Pair buttons. Paired devices persist in `SharedPreferences`.
- **Timeline** — the on-device library, grouped by day, with pull-to-refresh
  and a floating month scrubber. Demo mode seeds placeholder tiles.
- **Devices** — paired-device cards; *Backup now* queues only items that peer
  does not already have (SHA-256), resuming from the last acknowledged byte.
- **Transfers** — active queue with live progress + speed, cancel/retry,
  clear completed; simulated LAN throughput in demo mode.
- **Settings** — language, theme, auto-backup, backup folder, on-device
  duplicate search (exact SHA-256 and difference hash). Face grouping is
  still marked coming soon.

## Structure

```
lib/
  main.dart                      UncloudApp, MultiProvider, theme, OnboardingGate
  l10n/
    app_localizations.dart       Hand-written AppLocalizations (en + zh maps)
    locale_controller.dart       LocaleController ('system'|'en'|'zh', persisted)
  models/
    device.dart                  PeerDevice
    media_item.dart              MediaItem (photo/video/file)
    transfer_task.dart           TransferTask (queued/active/done/failed/cancelled)
    device_directory.dart        Peer table merge rules
  sync/
    sync_planner.dart            What a peer is still missing
    duplicate_assistant.dart     Exact + perceptual duplicate groups
    difference_hash.dart         64-bit dHash
  crypto/device_id.dart          deviceId = sha256(SPKI) prefix
  controllers/
    devices_controller.dart      Merges discovery + persisted paired devices
    transfer_controller.dart     Live task lists, speed estimates
    settings_controller.dart     Theme mode, auto-backup, backup folder
  services/
    discovery_service.dart       LAN discovery (demo peers; core TODO)
    pairing_service.dart         uncloud:// payload parse/build, persistence
    transfer_service.dart        Queue + transports (CLI / MethodChannel / demo)
    settings_service.dart        SharedPreferences-backed settings
  ui/
    onboarding/onboarding_page.dart
    pairing/pairing_page.dart
    home/home_shell.dart         NavigationBar: Timeline / Devices / Transfers
    timeline/timeline_page.dart
    devices/devices_page.dart
    transfers/transfers_page.dart
    settings/settings_page.dart
    widgets/empty_state.dart
    widgets/section_header.dart
test/
  widget_test.dart               Smoke tests (boot, nav, zh locale)
```

## Running

```bash
cd app
flutter pub get
flutter run            # any device / emulator / desktop
flutter analyze --fatal-infos
flutter test           # unit + widget tests
```

First launch follows the system locale (中文系统 → 简体中文), otherwise
English. Switch any time in **Settings → Language**.

## I18n guide

No codegen, no `.arb` files. All strings live in
`lib/l10n/app_localizations.dart`:

- `_strings['en']` is the source of truth; `_strings['zh']` must carry the
  same keys (missing keys fall back to English, then to the key itself).
- Add a string: add the key to both maps, add a getter like
  `String get myKey => _t('myKey');`, then use `context.l10n.myKey`.
- Placeholders use `{name}` syntax via `_p`, e.g.
  `l10n.pairingSuccess(device.name)`.
- The `context.l10n` extension (`AppLocalizationsX`) is the canonical lookup
  pattern — no UI string should be hard-coded.

## Roadmap — wiring the real core

The app is architected so the demo pieces are drop-in replaceable:

1. **Core sidecar (Rust or Node)** exposing a small CLI + JSON-lines API:
   `uncloud discover`, `uncloud pair`, `uncloud send/recv`, `uncloud stats`.
2. **FFI / IPC bridge**:
   - Desktop: `CliTransferTransport` already shells out to the CLI;
     swap `DiscoveryService`'s demo seeding for `Process.start('uncloud',
     ['discover'])` with JSON-lines stdout.
   - Mobile: embed the core via FFI and bridge over the
     `uncloud/transfer` / `uncloud/discovery` MethodChannels
     (`ChannelTransferTransport` is the stub).
3. **Real photo source**: replace `buildSampleLibrary()` with the camera
   roll (`photo_manager`) or the core's media index. The timeline already
   reads `LibraryController`.
4. **Local AI**: difference-hash dedupe runs in the app. Face clustering is
   still a coming-soon entry.

Everything stays on the user's own hardware — that is the product.
