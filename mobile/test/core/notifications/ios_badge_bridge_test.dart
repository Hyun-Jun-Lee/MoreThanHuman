import 'package:curitalk/core/notifications/ios_badge_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.morethanhuman.curitalk/badge');
  const bridge = IOSBadgeBridge();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'status'
              ? 'notDetermined'
              : call.method == 'request'
              ? 'allowed'
              : null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'permission read does not request and native writes carry only 0 or 1',
    () async {
      expect(await bridge.permission(), BadgePermission.notDetermined);
      expect(calls.map((c) => c.method), ['status']);
      expect(await bridge.permission(request: true), BadgePermission.allowed);
      await bridge.setCount(1);
      await bridge.setCount(0);
      expect(calls.skip(2).map((c) => c.arguments), [1, 0]);
    },
  );
  test('Android avoids the native channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await bridge.permission(request: true), BadgePermission.unsupported);
    expect(calls, isEmpty);
  });
  test(
    'unsupported native version does not become permission denied',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => 'unsupported');
      expect(await bridge.permission(), BadgePermission.unsupported);
    },
  );
}
