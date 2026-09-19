import 'package:flutter/material.dart';

/// Aplikasi finansial yang notifikasinya dibaca oleh SeaTrack.
enum TxSource {
  seabank('SeaBank', Color(0xFFF26F21)),
  dana('DANA', Color(0xFF108EE9)),
  gopay('GoPay', Color(0xFF00AED6)),
  manual('Manual', Color(0xFF6B7280));

  const TxSource(this.label, this.color);

  final String label;
  final Color color;

  /// Mencocokkan package name Android ke sumber yang didukung.
  static TxSource? fromPackage(String pkg) {
    final p = pkg.toLowerCase();
    if (p == 'id.co.bankbkemobile.digitalbank') return TxSource.seabank;
    if (p == 'id.dana') return TxSource.dana;
    if (p.contains('gopay') || p.contains('gojek')) return TxSource.gopay;
    return null;
  }

  /// Menebak sumber dari judul transaksi (prefix "SeaBank", "DANA", "GoPay").
  static TxSource fromTitle(String title) {
    final t = title.trimLeft().toLowerCase();
    for (final s in values) {
      if (s != manual && t.startsWith(s.label.toLowerCase())) return s;
    }
    return manual;
  }

  static const List<TxSource> supported = [seabank, dana, gopay];
}
