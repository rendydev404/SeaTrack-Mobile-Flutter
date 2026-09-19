import 'package:flutter_test/flutter_test.dart';
import 'package:seatrack/services/notification_bridge.dart';

void main() {
  group('NotifEvent.fromMap', () {
    // Sisi Android mengirim dua bentuk map yang berbeda. Untuk notifikasi aktif
    // hanya enam kunci yang diisi, dan itulah yang membuat pabrik bawaan paket
    // melempar "type 'Null' is not a subtype of type 'bool'".
    test('map notifikasi aktif yang hanya berisi enam kunci', () {
      final e = NotifEvent.fromMap({
        'id': 0,
        'packageName': 'id.co.bankbkemobile.digitalbank',
        'title': 'Pembayaran QRIS berhasil',
        'content': 'Pembayaran QRIS untuk PT SUKA PROFIT BERKAH sebesar 2 telah berhasil.',
        'onGoing': false,
        'postTime': 1789806647317,
      });
      expect(e, isNotNull);
      expect(e!.packageName, 'id.co.bankbkemobile.digitalbank');
      expect(e.title, 'Pembayaran QRIS berhasil');
      expect(e.timestamp, 1789806647317);
      expect(e.onGoing, isFalse);
      // Kunci yang tidak dikirim harus punya nilai bawaan, bukan melempar.
      expect(e.hasRemoved, isFalse);
    });

    test('judul dan isi yang null menjadi teks kosong', () {
      final e = NotifEvent.fromMap({
        'packageName': 'id.dana',
        'title': null,
        'content': null,
        'postTime': null,
      });
      expect(e, isNotNull);
      expect(e!.title, '');
      expect(e.content, '');
      expect(e.timestamp, 0);
    });

    test('tanpa packageName dianggap tidak sah', () {
      expect(NotifEvent.fromMap({'title': 'x'}), isNull);
      expect(NotifEvent.fromMap({'packageName': ''}), isNull);
    });

    test('notifikasi berjalan ditandai onGoing', () {
      final e = NotifEvent.fromMap({
        'packageName': 'com.gojek.gopay',
        'onGoing': true,
        'postTime': 1,
      });
      expect(e!.onGoing, isTrue);
    });
  });
}
