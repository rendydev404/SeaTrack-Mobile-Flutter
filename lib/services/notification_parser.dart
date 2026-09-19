import '../core/sources.dart';
import '../models/transaction.dart';

/// Parser murni (tanpa efek samping) untuk notifikasi SeaBank, DANA, dan GoPay.
///
/// Mengembalikan [TransactionModel] bila teks notifikasi benar-benar sebuah
/// transaksi dengan nominal yang bisa dibaca, selain itu `null`.
class NotificationParser {
  NotificationParser._();

  static const _incomeKeys = [
    'transfer masuk',
    'dana masuk',
    'uang masuk',
    'saldo masuk',
    'menerima',
    'diterima',
    'terima dana',
    'terima uang',
    'dikreditkan',
    'top up berhasil',
    'topup berhasil',
    'berhasil top up',
    'berhasil topup',
    'top-up berhasil',
    'bunga',
    'cashback',
    'refund',
    'pengembalian dana',
    'masuk',
  ];

  static const _expenseKeys = [
    'transfer keluar',
    'pembayaran',
    'berhasil bayar',
    'bayar',
    'qris',
    'didebit',
    'kirim uang',
    'berhasil kirim',
    'terkirim',
    'tarik tunai',
    'pembelian',
    'belanja',
    'dipakai',
    'transfer ke',
    'keluar',
  ];

  /// Notifikasi promosi sering menyebut nominal; ini harus diabaikan.
  static const _promoKeys = [
    'promo',
    'voucher',
    'diskon',
    'dapatkan',
    'raih',
    'yuk',
    'ayo',
    'gratis',
    'kesempatan',
    'segera',
    'jangan lewatkan',
    'menangkan',
    'hadiah',
    'undian',
    'bunga hingga',
    'kode otp',
    'otp',
  ];

  /// Frasa setelah "ke"/"dari" yang bukan nama lawan transaksi.
  static const _genericTargets = [
    'rekening',
    'saldo',
    'akun',
    'dompet',
    'kartu',
    'aplikasi',
  ];

  static final RegExp _amountRe = RegExp(
    r'(?:Rp|IDR)\s?\.?\s?([0-9][0-9.,]*[0-9]|[0-9])',
    caseSensitive: false,
  );

  /// Nominal yang ditulis setelah kata jumlah, tanpa "Rp" dan tanpa pemisah
  /// ribuan. SeaBank memakai bentuk ini, contoh "sebesar 2 telah berhasil".
  /// Kata jumlah menjadi jangkarnya supaya nomor referensi tidak ikut terbaca.
  static final RegExp _labeledAmountRe = RegExp(
    r'\b(?:sebesar|senilai|sejumlah)\s+(?:Rp|IDR)?\s*\.?\s*([0-9][0-9.,]*)',
    caseSensitive: false,
  );

  static final RegExp _fallbackAmountRe =
      RegExp(r'(?<![0-9])([0-9]{1,3}(?:\.[0-9]{3})+)(?![0-9])');
  /// "untuk" ikut dihitung karena SeaBank menyebut merchant QRIS dengan kata
  /// itu, contoh "Pembayaran QRIS untuk PT SUKA PROFIT BERKAH".
  static final RegExp _counterpartyRe = RegExp(
    r'\b(dari|ke|kepada|untuk)\s+([^\n]+?)(?=\s+(?:sebesar|senilai|sejumlah|rp|idr|pada|tanggal|berhasil|telah|sudah)\b|[.,!]|$)',
    caseSensitive: false,
  );

  static TransactionModel? parse({
    required String packageName,
    required String title,
    required String content,
    required int timestampMs,
  }) {
    final source = TxSource.fromPackage(packageName);
    if (source == null) return null;

    final text = '$title $content'.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (_promoKeys.any(lower.contains)) return null;

    final amount = extractAmount(text);
    if (amount == null || amount <= 0) return null;

    final type = classify(lower);
    if (type == null) return null;

    final desc = _describe(text, type);
    return TransactionModel(
      title: '${source.label} · $desc',
      amount: amount,
      type: type,
      createdAt: DateTime.fromMillisecondsSinceEpoch(timestampMs),
    );
  }

  /// Menentukan jenis transaksi. Kata kunci diurutkan dari yang paling spesifik.
  static TxType? classify(String lower) {
    final inIdx = _firstIndex(lower, _incomeKeys);
    final outIdx = _firstIndex(lower, _expenseKeys);
    final hasIn = inIdx >= 0;
    final hasOut = outIdx >= 0;

    if (hasIn && !hasOut) return TxType.income;
    if (hasOut && !hasIn) return TxType.expense;
    if (hasIn && hasOut) {
      // Keduanya cocok: gunakan preposisi sebagai penentu, lalu posisi kata.
      if (lower.contains(' dari ') && !lower.contains(' ke ')) return TxType.income;
      if (lower.contains(' ke ') && !lower.contains(' dari ')) return TxType.expense;
      return inIdx < outIdx ? TxType.income : TxType.expense;
    }
    if (lower.contains(' dari ')) return TxType.income;
    if (lower.contains(' ke ')) return TxType.expense;
    return null;
  }

  static int _firstIndex(String text, List<String> keys) {
    var best = -1;
    for (final k in keys) {
      final i = text.indexOf(k);
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }

  /// Mengubah "50.000", "50.000,00", "50,000", "50,000.00", "50000" ke angka.
  ///
  /// Urutannya dari yang paling meyakinkan: nominal berprefix "Rp", lalu
  /// nominal setelah kata jumlah, baru angka berpemisah ribuan.
  static double? extractAmount(String text) {
    var raw = _amountRe.firstMatch(text)?.group(1) ??
        _labeledAmountRe.firstMatch(text)?.group(1) ??
        _fallbackAmountRe.firstMatch(text)?.group(1);
    if (raw == null) return null;
    raw = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (raw.isEmpty) return null;

    final lastSep = raw.lastIndexOf(RegExp(r'[.,]'));
    String intPart;
    String fracPart = '';
    if (lastSep >= 0 && raw.length - lastSep - 1 <= 2) {
      // Pemisah terakhir diikuti 1-2 digit: itu desimal.
      intPart = raw.substring(0, lastSep);
      fracPart = raw.substring(lastSep + 1);
    } else {
      intPart = raw;
    }
    intPart = intPart.replaceAll(RegExp(r'[.,]'), '');
    if (intPart.isEmpty) return null;
    return double.tryParse(fracPart.isEmpty ? intPart : '$intPart.$fracPart');
  }

  static String _describe(String text, TxType type) {
    // Lawan transaksi: "dari X" untuk pemasukan, "ke X" atau "untuk X" untuk
    // pengeluaran. Arah yang tidak sesuai jenis transaksi dilewati.
    for (final m in _counterpartyRe.allMatches(text)) {
      final isDari = m.group(1)!.toLowerCase() == 'dari';
      if (isDari != (type == TxType.income)) continue;
      final name = _clean(m.group(2)!);
      if (name.isEmpty || name.length > 40) continue;
      if (_genericTargets.any(name.toLowerCase().startsWith)) continue;
      return '${isDari ? 'Dari' : 'Ke'} $name';
    }
    final lower = text.toLowerCase();
    if (lower.contains('qris')) return 'Pembayaran QRIS';
    if (lower.contains('top up') || lower.contains('topup') || lower.contains('top-up')) {
      return 'Top Up';
    }
    if (lower.contains('bunga')) return 'Bunga';
    if (lower.contains('cashback')) return 'Cashback';
    if (lower.contains('refund') || lower.contains('pengembalian')) return 'Refund';
    if (lower.contains('tarik tunai')) return 'Tarik Tunai';
    return type == TxType.income ? 'Transfer Masuk' : 'Transfer Keluar';
  }

  static String _clean(String s) {
    var out = s.trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    out = out.replaceAll(RegExp(r'[*"“”]'), '');
    // Buang nomor rekening/kartu yang panjang agar judul tetap ringkas.
    out = out.replaceAll(RegExp(r'\b[0-9]{6,}\b'), '').trim();
    if (out.length > 40) out = '${out.substring(0, 37).trimRight()}…';
    return out;
  }
}
