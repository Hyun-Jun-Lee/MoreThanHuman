import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BadgePermission { unsupported, notDetermined, denied, allowed }

class IOSBadgeBridge {
  const IOSBadgeBridge();
  static const _channel = MethodChannel('com.morethanhuman.curitalk/badge');

  Future<BadgePermission> permission({bool request = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return BadgePermission.unsupported;
    }
    try {
      final value = await _channel.invokeMethod<String>(
        request ? 'request' : 'status',
      );
      return BadgePermission.values.firstWhere(
        (p) => p.name == value,
        orElse: () => BadgePermission.unsupported,
      );
    } on MissingPluginException {
      return BadgePermission.unsupported;
    } on PlatformException {
      return BadgePermission.unsupported;
    }
  }

  Future<void> setCount(int count) => _channel.invokeMethod('set', count);
  Future<void> openSettings() => _channel.invokeMethod('settings');
}

final iosBadgeBridgeProvider = Provider((ref) => const IOSBadgeBridge());
