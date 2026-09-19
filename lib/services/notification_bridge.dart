import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_event.dart';

/// Notifikasi yang sudah dinormalkan, sumbernya bisa aliran langsung maupun
/// sapuan panel notifikasi.
@immutable
class NotifEvent {
  final String packageName;
  final String title;
  final String content;
  final int timestamp;
  final bool onGoing;
  final bool hasRemoved;

  const NotifEvent({
    required this.packageName,
    required this.title,
    required this.content,
    required this.timestamp,
    this.onGoing = false,
    this.hasRemoved = false,
  });

  factory NotifEvent.fromService(ServiceNotificationEvent e) => NotifEvent(
        packageName: e.packageName,
        title: e.title,
        content: e.content,
        timestamp: e.timestamp,
        onGoing: e.onGoing,
        hasRemoved: e.hasRemoved,
      );

  /// Memetakan satu baris hasil `getActiveNotifications` dari sisi Android.
  ///
  /// Sengaja longgar: sisi native hanya mengirim enam kunci untuk notifikasi
  /// aktif, sedangkan aliran langsung mengirim dua belas. Memaksakan tipe di
  /// sini membuat seluruh sapuan gagal hanya karena satu kunci tidak ada.
  static NotifEvent? fromMap(Map<Object?, Object?> map) {
    final pkg = map['packageName'];
    if (pkg is! String || pkg.isEmpty) return null;
    return NotifEvent(
      packageName: pkg,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      timestamp: (map['postTime'] as num?)?.toInt() ?? 0,
      onGoing: map['onGoing'] as bool? ?? false,
      hasRemoved: map['hasRemoved'] as bool? ?? false,
    );
  }
}

/// Akses langsung ke kanal milik `notification_listener_service`.
///
/// Fungsi `getActiveNotifications()` bawaan paket versi 1.0.0 selalu melempar
/// `type 'Null' is not a subtype of type 'bool'`, karena pabrik modelnya
/// mewajibkan `haveExtraPicture` padahal sisi native tidak pernah mengirimnya
/// untuk notifikasi aktif. Aliran langsungnya sendiri tidak bermasalah, jadi
/// hanya bagian inilah yang dilewati.
class NotificationBridge {
  NotificationBridge._();

  static const _channel = MethodChannel('x-slayer/notifications_channel');

  /// Notifikasi yang masih tampil di panel. Kosong bila layanan belum berjalan.
  static Future<List<NotifEvent>> activeNotifications() async {
    if (!Platform.isAndroid) return const [];
    final raw = await _channel.invokeMethod<List<Object?>>('getActiveNotifications');
    if (raw == null) return const [];
    return [
      for (final item in raw)
        if (item is Map<Object?, Object?>)
          if (NotifEvent.fromMap(item) case final e?) e,
    ];
  }
}
