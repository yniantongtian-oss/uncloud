import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uncloud/crypto/device_id.dart';

void main() {
  test('device id is the first 16 hex chars of sha256(SPKI)', () {
    const pub = 'MCowBQYDK2VwAyEAaq0MKjBE_MgbcWQMOg1DOcjZ_iA3H2o_Vx-62ZrwXIE';
    final der = decodeBase64Url(pub);
    expect(der, isNotNull);
    expect(deviceIdFromSpki(der!), 'e30dcad8c0916ccd');
  });

  test('base64url decode accepts missing padding and rejects garbage', () {
    expect(decodeBase64Url('YQ'), isNotNull);
    expect(decodeBase64Url('***'), isNull);
    expect(decodeBase64Url(''), isNull);
  });

  test('empty SPKI is rejected', () {
    expect(() => deviceIdFromSpki(Uint8List(0)), throwsArgumentError);
  });
}
