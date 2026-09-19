import 'dart:io';

import 'package:flutter/services.dart';

/// Akses ke pengaturan optimasi baterai Android lewat MethodChannel kecil,
/// tanpa menambah dependensi pihak ketiga.
class BatteryService {
  BatteryService._();

  static const _channel = MethodChannel('seatrack/battery');

  static Future<bool> isIgnoringOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoring') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> requestIgnore() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('request');
    } on PlatformException {
      // Pengguna bisa mengaturnya manual dari pengaturan sistem.
    } on MissingPluginException {
      // Berjalan di platform tanpa implementasi native.
    }
  }
}
