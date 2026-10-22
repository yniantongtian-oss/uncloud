import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uncloud/services/pairing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = PairingService();

  String corePayload(Map<String, Object?> fields) {
    return 'uncloud://${base64Url.encode(utf8.encode(jsonEncode(fields)))}';
  }

  const pub = 'MCowBQYDK2VwAyEAaq0MKjBE_MgbcWQMOg1DOcjZ_iA3H2o_Vx-62ZrwXIE';

  Map<String, Object?> validFields({Object? port = 47778, String? deviceId}) {
    return {
      'v': 1,
      'deviceId': deviceId ?? 'e30dcad8c0916ccd',
      'name': 'Laptop',
      'host': '10.0.0.8',
      'port': port,
      'pub': pub,
    };
  }

  test('rejects a device id that does not match the public key', () {
    final raw = corePayload(validFields(deviceId: '0123456789abcdef'));
    expect(service.parsePayload(raw), isNull);
  });

  test('rejects unsupported versions, bad ports, and a missing key', () {
    expect(
      service.parsePayload(corePayload({...validFields(), 'v': 2})),
      isNull,
    );
    expect(service.parsePayload(corePayload(validFields(port: 0))), isNull);
    expect(service.parsePayload(corePayload(validFields(port: 70000))), isNull);
    expect(
      service.parsePayload(
        'uncloud://${base64Url.encode(utf8.encode('{"v":1,"deviceId":"e30dcad8c0916ccd","name":"Laptop","host":"10.0.0.8","port":47778.5,"pub":"$pub"}'))}',
      ),
      isNull,
    );
    final withoutKey = {...validFields()}..remove('pub');
    expect(service.parsePayload(corePayload(withoutKey)), isNull);
  });

  test('accepts a numeric port encoded as a string', () {
    final device = service.parsePayload(
      corePayload(validFields(port: '47778')),
    );
    expect(device, isNotNull);
    expect(device!.port, 47778);
    expect(device.publicKey, pub);
    expect(device.deviceId, 'e30dcad8c0916ccd');
  });

  test('legacy query form still parses and rejects an impossible port', () {
    expect(
      service.parsePayload(
        'uncloud://pair/abc123?name=Phone&host=192.168.1.8&port=0',
      ),
      isNull,
    );
    expect(
      service.parsePayload(
        'uncloud://pair/abc123?name=Phone&host=192.168.1.8&port=99999',
      ),
      isNull,
    );
  });

  test('corrupt paired-device storage does not throw', () async {
    SharedPreferences.setMockInitialValues({
      'uncloud.pairedDevices': 'not-json',
    });
    expect(await PairingService().loadPaired(), isEmpty);

    SharedPreferences.setMockInitialValues({
      'uncloud.pairedDevices': jsonEncode([
        {
          'deviceId': 'ok',
          'name': 'Phone',
          'host': '10.0.0.2',
          'port': 47778,
          'isPaired': true,
          'lastSeen': '2026-01-01T00:00:00.000Z',
        },
        {'deviceId': 'broken'},
      ]),
    });
    final loaded = await PairingService().loadPaired();
    expect(loaded, hasLength(1));
    expect(loaded.single.deviceId, 'ok');
  });

  test('store replaces a paired device with the same id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final pairing = PairingService();
    final first = pairing.parsePayload(
      'uncloud://pair/abc123?name=Phone&host=192.168.1.8&port=47778',
    );
    final renamed = pairing.parsePayload(
      'uncloud://pair/abc123?name=New%20Phone&host=192.168.1.9&port=47779',
    );
    expect(first, isNotNull);
    expect(renamed, isNotNull);
    await pairing.storePaired(first!);
    await pairing.storePaired(renamed!);
    final stored = await pairing.loadPaired();
    expect(stored, hasLength(1));
    expect(stored.single.name, 'New Phone');
    expect(stored.single.port, 47779);
  });
}
