import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SnackWidgetBridge {
  Future<String?> read();
  Future<void> write(String snapshot);
  Future<void> clear();
}

class IosSnackWidgetBridge implements SnackWidgetBridge {
  const IosSnackWidgetBridge();

  static const _channel = MethodChannel(
    'com.morethanhuman.curitalk/snack_widget',
  );

  bool get _supported => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<String?> read() => _supported
      ? _channel.invokeMethod<String>('read')
      : Future<String?>.value();

  @override
  Future<void> write(String snapshot) => _supported
      ? _channel.invokeMethod<void>('write', snapshot)
      : Future<void>.value();

  @override
  Future<void> clear() =>
      _supported ? _channel.invokeMethod<void>('clear') : Future<void>.value();
}

final snackWidgetBridgeProvider = Provider<SnackWidgetBridge>(
  (ref) => const IosSnackWidgetBridge(),
);
