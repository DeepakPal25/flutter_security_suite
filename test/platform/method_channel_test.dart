import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_security_suite/platform/method_channel_security.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelSecurity sut;
  final List<MethodCall> log = [];

  setUp(() {
    sut = MethodChannelSecurity();
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelSecurity.channel, (
          MethodCall call,
        ) async {
          log.add(call);
          switch (call.method) {
            case 'root#isDeviceRooted':
              return true;
            case 'integrity#isValid':
              return false;
            case 'storage#read':
              return 'secret_value';
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannelSecurity.channel, null);
  });

  group('MethodChannelSecurity', () {
    test('isDeviceRooted sends correct method and returns result', () async {
      final result = await sut.isDeviceRooted();
      expect(result, isTrue);
      expect(log.single.method, 'root#isDeviceRooted');
    });

    test('enableScreenshotProtection sends correct method', () async {
      await sut.enableScreenshotProtection();
      expect(log.single.method, 'screenshot#enable');
    });

    test('disableScreenshotProtection sends correct method', () async {
      await sut.disableScreenshotProtection();
      expect(log.single.method, 'screenshot#disable');
    });

    test(
      'isAppIntegrityValid sends correct method and returns result',
      () async {
        final result = await sut.isAppIntegrityValid();
        expect(result, isFalse);
        expect(log.single.method, 'integrity#isValid');
      },
    );

    test('secureStorageWrite sends correct method with args', () async {
      await sut.secureStorageWrite(key: 'k', value: 'v');
      expect(log.single.method, 'storage#write');
      expect(log.single.arguments, {'key': 'k', 'value': 'v'});
    });

    test('secureStorageRead sends correct method and returns value', () async {
      final result = await sut.secureStorageRead(key: 'k');
      expect(result, 'secret_value');
      expect(log.single.method, 'storage#read');
      expect(log.single.arguments, {'key': 'k'});
    });

    test('secureStorageDelete sends correct method with key', () async {
      await sut.secureStorageDelete(key: 'k');
      expect(log.single.method, 'storage#delete');
      expect(log.single.arguments, {'key': 'k'});
    });

    test('secureStorageDeleteAll sends correct method', () async {
      await sut.secureStorageDeleteAll();
      expect(log.single.method, 'storage#deleteAll');
    });
  });
}
