# Uncloud Protocol Specification

Version: **1** · Status: implemented in `core/` (v0.1.0)

Uncloud is a LAN-only protocol. There are four phases: **identity → discovery → pairing → transfer**, plus a local **index** for metadata. Nothing in this document involves any internet host.

## 1. Identity

Each device generates an **ed25519** keypair locally using `node:crypto` (`crypto.generateKeyPairSync('ed25519')`). The keypair is created once on first run (`uncloud id`) and persisted; the private key never leaves the device.

The **device ID** is derived from the public key:

```
deviceId = sha256( publicKey.export({type:'spki', format:'der'}) ).hex[0..15]
```

i.e. the first 16 hexadecimal characters (64 bits) of the SHA-256 digest of the SPKI-DER-encoded public key.

Example: `deviceId: 3f9a1c72b0e4d85a`

Rationale: binding the ID to the *key* (not a random string) means any peer can later verify that a signature or key exchange came from the device that was paired, without a central registry.

## 2. Discovery

Devices find each other via **UDP multicast**:

| Parameter | Value |
| --------- | ----- |
| Group | `239.255.77.77` |
| Port | `47777` |
| Announce interval | every **2 s** |
| Peer expiry | **8 s** without an announce |

Each announce is a single UDP datagram containing JSON:

```json
{
  "v": 1,
  "deviceId": "3f9a1c72b0e4d85a",
  "name": "Kitchen-PC",
  "port": 47778
}
```

- `v` — protocol version (see §6).
- `name` — human-readable device name, shown in the UI peer list.
- `port` — the TCP port the device is listening on for transfers (§4).

Receivers maintain a peer table keyed by `deviceId`; a peer that has not announced within 8 s is considered gone and removed. Discovery answers *"who is here and how do I reach them"* — it grants **no trust** by itself (that's pairing, §3).

`uncloud scan` is a passive observer for this phase: it listens and prints peers without announcing.

## 3. Pairing

Pairing happens **in person via QR code** and establishes the trust relationship. One device displays, the other scans.

The QR payload is:

```
uncloud://<base64url(JSON)>
```

where the JSON is:

```json
{
  "v": 1,
  "deviceId": "3f9a1c72b0e4d85a",
  "name": "Kitchen-PC",
  "host": "192.168.1.20",
  "port": 47778,
  "pub": "MCowBQYDK2VwAyEA…base64url-of-spki-der…"
}
```

| Field | Meaning |
| ----- | ------- |
| `v` | protocol version |
| `deviceId` | must match `sha256(spki-der(pub))[0..15]` — the scanner **must verify** this |
| `name` | display name |
| `host` / `port` | where to reach the device right now (hint; discovery remains authoritative) |
| `pub` | base64url of the SPKI-DER ed25519 public key |

On scan, the device stores the peer (`deviceId`, `name`, `pub`) in its trusted-peers list. From then on, transfers are only accepted from paired devices. `uncloud pair` prints the local payload for QR rendering; the app renders the QR itself.

## 4. Transfer

Transfer is a single **TCP** connection from sender to receiver (`uncloud send` → `uncloud serve`). Framing:

```
sender ──▶ receiver:  {"name":"IMG_2048.jpg","size":3481204,"sha256":"9b2c…"}\n
sender ──▶ receiver:  <raw file bytes, streamed in 64 KB chunks>
receiver ──▶ sender:  {"ok":true}\n
```

1. **Header** — exactly one line: a JSON object `{name, size, sha256}` terminated by `\n`.
   - `name` — file name only (no directories; see path sanitization in §5 and the security model in [architecture.md](architecture.md)).
   - `size` — byte length of the payload that follows.
   - `sha256` — lowercase hex SHA-256 of the payload.
2. **Payload** — exactly `size` raw bytes, streamed in chunks of at most **64 KB** (65536 bytes). The receiver must not buffer the whole file in memory; it hashes incrementally while writing to disk.
3. **Reply** — after all `size` bytes arrive, the receiver recomputes the SHA-256. On match it finalizes the file and replies one JSON line `{"ok":true}`. Only after receiving `{ok:true}` does the sender report success.

### Error cases

| Situation | Receiver behavior |
| --------- | ----------------- |
| Malformed header (not JSON, missing fields) | Reply `{"ok":false,"error":"bad_header"}`, close connection, delete partial file |
| Connection drops mid-payload | Delete partial file; sender may retry by reconnecting |
| Fewer/more bytes than `size` | `{"ok":false,"error":"bad_size"}`, delete partial file |
| SHA-256 mismatch | `{"ok":false,"error":"bad_checksum"}`, delete partial file |
| Unpaired sender | Refuse immediately: `{"ok":false,"error":"unpaired"}` |
| Filename sanitizes to empty / collision | Reject (`bad_name`) or rename with a numeric suffix — never silently overwrite |

A transfer is **atomic** from the user's point of view: the file is written to a temporary name and only moved into place after the checksum passes.

## 5. Index

Each device keeps a **local JSON metadata store** describing what it has received and sent: file name, size, sha256, timestamp, peer `deviceId`, and local path. The index is metadata only — the files themselves live as ordinary files in ordinary folders, browsable with any tool.

> All data stays on the user's devices. There is no sync to any third party, no telemetry, and no "phone home" — not now, not ever.

## 6. Versioning

- The protocol version `v` appears in **every** discovery announce and pairing payload. Current: `1`.
- Peers with a higher `v` than understood must be ignored (never guessed at).
- New versions must be **additive within a major version**: new optional JSON fields are fine; changing the meaning of `v:1` messages is not. Breaking changes bump `v` and ship alongside parsers for the previous version for at least one release.

## 7. Future: end-to-end encryption (v0.2)

Today, integrity is guaranteed (SHA-256) and trust is bound to ed25519 identity, but the wire itself is plaintext — acceptable on a trusted home LAN, not on a café network. v0.2 upgrades the transfer phase:

1. **Key exchange** — both peers derive ephemeral **X25519** keys and exchange them at connection start; each signs its ephemeral key with its long-term ed25519 identity key, preventing MITM (the signature is verifiable against the `pub` learned at pairing time).
2. **Shared secret** — X25519 ECDH, then HKDF-SHA-256 over the connection transcript to derive the session key.
3. **Transport encryption** — every 64 KB chunk becomes a **ChaCha20-Poly1305** record with an incrementing nonce; the header line is included as associated data, so tampering with `name`/`size`/`sha256` breaks authentication.
4. **Integrity** — the SHA-256 check stays as a second, independent layer (defense in depth), and the `{ok}` reply is also encrypted.

The encrypted handshake will be negotiated with a new `v` value, keeping v1 plaintext peers interoperable during the transition.