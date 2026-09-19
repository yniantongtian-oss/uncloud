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
- **Timeline** — photos/videos grouped by day (Today / Yesterday / full date),
  pull-to-refresh, and a floating month scrubber label. Demo data is
  deterministic placeholder tiles (no real photos needed).
- **Devices** — paired-device cards with online dot, last-seen, storage bar;
  tap for a detail sheet with *Browse files* (stub), *Backup now* (queues
  demo transfers) and *Unpair*.
- **Transfers** — active queue with live progress + speed, cancel/retry,
  clear-history; simulated LAN throughput in demo mode.
- **Settings** — Language (English / 简体中文 / Follow system), Theme
  (System / Light / Dark), auto-backup switch + backup-folder picker
  (`file_picker`), local-AI "coming soon" stubs (dedupe, faces), About with
  version and license page.

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
    transfer_task.dart           TransferTask (queued/active/done/failed)
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
flutter test           # widget smoke tests
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
3. **Real photo source**: replace `_buildSampleItems()` in the timeline with
   the core's media index (or `photo_manager` on-device).
4. **Local AI**: dedupe (perceptual hash) and face clustering run in the
   core; the UI entries already exist behind "coming soon" chips.

Everything stays on the user's own hardware — that is the product.
