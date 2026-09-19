import 'package:flutter_test/flutter_test.dart';
import 'package:uncloud/services/pairing_service.dart';

void main() {
  final service = PairingService();

  test('parses core CLI uncloud:// + base64url JSON payload', () {
    const raw =
        'uncloud://eyJ2IjoxLCJkZXZpY2VJZCI6ImUzMGRjYWQ4YzA5MTZjY2QiLCJuYW1lIjoiTEFQVE9QLUVTNlZWVVY4IiwiaG9zdCI6IjEyNy4wLjAuMSIsInBvcnQiOjQ3Nzc4LCJwdWIiOiJNQ293QlFZREsyVndBeUVBYXEwTUtqQkVfTWdiY1dRTU9nMURPY2paX2lBM0gyb19WeC02Mlpyd1hJRSJ9';
    final device = service.parsePayload(raw);
    expect(device, isNotNull);
    expect(device!.deviceId, 'e30dcad8c0916ccd');
    expect(device.name, 'LAPTOP-ES6VVUV8');
    expect(device.host, '127.0.0.1');
    expect(device.port, 47778);
  });

  test('parses query-string pairing payload', () {
    const raw =
        'uncloud://pair/abc123?name=Phone&host=192.168.1.8&port=47778';
    final device = service.parsePayload(raw);
    expect(device, isNotNull);
    expect(device!.deviceId, 'abc123');
    expect(device.name, 'Phone');
    expect(device.host, '192.168.1.8');
    expect(device.port, 47778);
  });

  test('rejects garbage', () {
    expect(service.parsePayload('https://example.com'), isNull);
    expect(service.parsePayload('uncloud://not-json'), isNull);
  });
}
