import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// First 16 hex characters of `sha256(SPKI DER)`.
///
/// This is the device id defined by the core engine. Pairing must recompute
/// it from `pub` and reject the payload when the advertised id does not match.
String deviceIdFromSpki(Uint8List spkiDer) {
  if (spkiDer.isEmpty) {
    throw ArgumentError.value(spkiDer, 'spkiDer', 'must be non-empty');
  }
  return sha256.convert(spkiDer).toString().substring(0, 16);
}

/// Decodes unpadded or padded base64url. Returns null on malformed input.
Uint8List? decodeBase64Url(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  try {
    var normalized = trimmed.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder != 0) {
      normalized += '=' * (4 - remainder);
    }
    return base64Decode(normalized);
  } on FormatException {
    return null;
  }
}
