import 'dart:io';

import 'package:flutter/services.dart';

/// Tahapan pembaruan, cerminan dari konstanta di AppUpdateManager.kt.
enum UpdateState {
  idle,
  checking,
  available,
  downloading,
  ready,
  installing,
  needsPermission,
  failed;

  static UpdateState parse(String? v) => switch (v) {
        'checking' => checking,
        'available' => available,
        'downloading' => downloading,
        'ready' => ready,
        'installing' => installing,
        'needsPermission' => needsPermission,
        'failed' => failed,
        _ => idle,
      };

  bool get isBusy =>
      this == checking || this == downloading || this == installing;
}

/// Keterangan rilis yang tersedia, dikirim dari manifest JSON.
class UpdateRelease {
  final int versionCode;
  final String versionName;
  final int? sizeBytes;
  final String? notes;
  final bool mandatory;

  const UpdateRelease({
    required this.versionCode,
    required this.versionName,
    this.sizeBytes,
    this.notes,
    this.mandatory = false,
  });

  static UpdateRelease? fromMap(Map<Object?, Object?>? map) {
    if (map == null) return null;
    final code = (map['versionCode'] as num?)?.toInt();
    if (code == null || code <= 0) return null;
    return UpdateRelease(
      versionCode: code,
      versionName: (map['versionName'] as String?) ?? '$code',
      sizeBytes: (map['apkSizeBytes'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      mandatory: (map['mandatory'] as bool?) ?? false,
    );
  }

  /// Ukuran APK penuh, `null` bila manifest tidak menyebutkannya.
  String? get sizeLabel => formatBytes(sizeBytes);

  static String? formatBytes(int? b) {
    if (b == null || b <= 0) return null;
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Potret status pembaruan pada satu saat.
class UpdateStatus {
  final UpdateState state;
  final int progress;
  final String? error;
  final String currentVersionName;
  final UpdateRelease? release;
  final bool canInstall;
  final bool configured;
  final String? justInstalledVersion;

  /// Benar bila yang diunduh adalah patch selisih, bukan APK penuh.
  final bool isDelta;

  /// Ukuran berkas yang sedang diunduh: patch atau APK penuh.
  final int? payloadSizeBytes;

  const UpdateStatus({
    this.state = UpdateState.idle,
    this.progress = 0,
    this.error,
    this.currentVersionName = '1.0.0',
    this.release,
    this.canInstall = false,
    this.configured = false,
    this.justInstalledVersion,
    this.isDelta = false,
    this.payloadSizeBytes,
  });

  /// Keterangan singkat unduhan, contoh "patch 820 KB" atau "54.1 MB".
  String? get payloadLabel {
    final size = UpdateRelease.formatBytes(payloadSizeBytes);
    if (size == null) return isDelta ? 'patch hemat' : null;
    return isDelta ? 'patch $size' : size;
  }

  static UpdateStatus fromMap(Map<Object?, Object?> map) => UpdateStatus(
        state: UpdateState.parse(map['state'] as String?),
        progress: (map['progress'] as num?)?.toInt() ?? 0,
        error: map['error'] as String?,
        currentVersionName:
            (map['currentVersionName'] as String?) ?? '1.0.0',
        release: UpdateRelease.fromMap(
          map['manifest'] as Map<Object?, Object?>?,
        ),
        canInstall: (map['canInstall'] as bool?) ?? false,
        configured: (map['configured'] as bool?) ?? false,
        justInstalledVersion: map['justInstalledVersion'] as String?,
        isDelta: (map['isDelta'] as bool?) ?? false,
        payloadSizeBytes: (map['payloadSizeBytes'] as num?)?.toInt(),
      );
}

/// Pembungkus tipis MethodChannel dan EventChannel modul pembaruan native.
class UpdateService {
  UpdateService._();

  static const _method = MethodChannel('seatrack/update');
  static const _events = EventChannel('seatrack/update/events');

  static bool get supported => Platform.isAndroid;

  static Stream<UpdateStatus> get statusStream => _events
      .receiveBroadcastStream()
      .map((e) => UpdateStatus.fromMap(e as Map<Object?, Object?>));

  static Future<UpdateStatus?> initialize(String manifestUrl) =>
      _invoke('initialize', {'manifestUrl': manifestUrl});

  static Future<void> check({bool force = false}) =>
      _call('check', {'force': force});

  static Future<void> install() => _call('install');

  static Future<void> continueWithUserAction() =>
      _call('continueWithUserAction');

  static Future<void> resumeAfterPermission() => _call('resumeAfterPermission');

  static Future<void> acknowledgeInstall() => _call('acknowledgeInstall');

  static Future<void> requestOverlayPermission() =>
      _call('requestOverlayPermission');

  static Future<UpdateStatus?> _invoke(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    if (!supported) return null;
    try {
      final result = await _method.invokeMethod<Map<Object?, Object?>>(method, args);
      return result == null ? null : UpdateStatus.fromMap(result);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!supported) return;
    try {
      await _method.invokeMethod<void>(method, args);
    } on PlatformException {
      // Kegagalan dilaporkan lewat status stream, bukan lewat pengecualian.
    } on MissingPluginException {
      // Berjalan di platform tanpa modul pembaruan.
    }
  }
}
