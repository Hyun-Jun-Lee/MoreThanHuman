import 'dart:math';

import 'package:curitalk/core/storage/token_storage.dart';

typedef InstallationIdGenerator = String Function();

class InstallationIdService {
  InstallationIdService(
    this.tokenStorage, {
    InstallationIdGenerator? generateId,
  }) : _generateId = generateId ?? _generateUuidV4;

  final TokenStorage tokenStorage;
  final InstallationIdGenerator _generateId;

  Future<String> getOrCreate() async {
    final String? storedId = await tokenStorage.readDeviceId();
    if (storedId != null && storedId.isNotEmpty) {
      return storedId;
    }

    final String installationId = _generateId();
    await tokenStorage.writeDeviceId(installationId);
    return installationId;
  }

  static String _generateUuidV4() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String value = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
