import 'package:flutter_test/flutter_test.dart';
import 'package:seatrack/core/sources.dart';
import 'package:seatrack/models/transaction.dart';
import 'package:seatrack/services/notification_parser.dart';

const seabank = 'id.co.bankbkemobile.digitalbank';
const dana = 'id.dana';
const gopay = 'com.gojek.gopay';

TransactionModel? parse(String pkg, String title, String content) =>
    NotificationParser.parse(
      packageName: pkg,
      title: title,
      content: content,
      timestampMs: 1720000000000,
    );

void main() {
  group('extractAmount', () {
    test('format Indonesia dengan titik ribuan', () {
      expect(NotificationParser.extractAmount('Rp50.000'), 50000);
      expect(NotificationParser.extractAmount('Rp 1.250.000'), 1250000);
      expect(NotificationParser.extractAmount('IDR 75.000'), 75000);
    });

    test('desimal koma tidak dianggap ribuan', () {
      expect(NotificationParser.extractAmount('Rp 50.000,00'), 50000);
      expect(NotificationParser.extractAmount('Rp 12.500,50'), 12500.5);
    });

    test('format koma ribuan dan titik desimal', () {
      expect(NotificationParser.extractAmount('Rp 50,000'), 50000);
      expect(NotificationParser.extractAmount('Rp 50,000.00'), 50000);
    });

    test('tanpa pemisah dan tanpa prefix', () {
      expect(NotificationParser.extractAmount('Rp25000'), 25000);
      expect(NotificationParser.extractAmount('sebesar 25.000 ke Budi'), 25000);
    });

    test('titik akhir kalimat diabaikan', () {
      expect(NotificationParser.extractAmount('Rp 10.000.'), 10000);
    });

    test('tidak ada nominal', () {
      expect(NotificationParser.extractAmount('Selamat pagi'), isNull);
    });
  });

  group('parse SeaBank', () {
    test('transfer masuk', () {
      final tx = parse(seabank, 'Transfer Masuk', 'Anda menerima Rp 150.000 dari BUDI SANTOSO');
      expect(tx, isNotNull);
      expect(tx!.type, TxType.income);
      expect(tx.amount, 150000);
      expect(tx.source, TxSource.seabank);
      expect(tx.description, 'Dari BUDI SANTOSO');
    });

    test('transfer keluar', () {
      final tx = parse(seabank, 'Transfer Berhasil', 'Transfer Rp 200.000 ke ANI WIJAYA berhasil');
      expect(tx!.type, TxType.expense);
      expect(tx.amount, 200000);
      expect(tx.description, 'Ke ANI WIJAYA');
    });

    test('pembayaran QRIS', () {
      final tx = parse(seabank, 'Pembayaran Berhasil', 'Pembayaran QRIS Rp 25.000 berhasil');
      expect(tx!.type, TxType.expense);
      expect(tx.description, 'Pembayaran QRIS');
    });

    test('bunga harian', () {
      final tx = parse(seabank, 'Bunga', 'Bunga sebesar Rp 1.234 telah dikreditkan ke rekening Anda');
      expect(tx!.type, TxType.income);
      expect(tx.amount, 1234);
      expect(tx.description, 'Bunga');
    });

    test('preposisi yang berlawanan arah diabaikan', () {
      final tx = parse(seabank, 'Transfer Masuk', 'Rp 90.000 dari SITI telah masuk ke rekening Anda');
      expect(tx!.type, TxType.income);
      expect(tx.description, 'Dari SITI');
    });
  });

  group('parse DANA dan GoPay', () {
    test('DANA terima uang', () {
      final tx = parse(dana, 'DANA', 'Kamu menerima Rp50.000 dari RINA');
      expect(tx!.source, TxSource.dana);
      expect(tx.type, TxType.income);
      expect(tx.title, startsWith('DANA · '));
    });

    test('GoPay bayar', () {
      final tx = parse(gopay, 'GoPay', 'Pembayaran Rp18.000 ke Kopi Kenangan berhasil');
      expect(tx!.source, TxSource.gopay);
      expect(tx.type, TxType.expense);
      expect(tx.description, 'Ke Kopi Kenangan');
    });

    test('GoPay top up', () {
      final tx = parse(gopay, 'Top up berhasil', 'Saldo GoPay kamu bertambah Rp100.000');
      expect(tx!.type, TxType.income);
      expect(tx.description, 'Top Up');
    });
  });

  group('diabaikan', () {
    test('aplikasi lain', () {
      expect(parse('com.whatsapp', 'Budi', 'Transfer Rp 50.000 dari saya ya'), isNull);
    });

    test('promo dengan nominal', () {
      expect(parse(seabank, 'Promo!', 'Dapatkan cashback Rp 20.000 untuk transaksi pertama'), isNull);
      expect(parse(dana, 'DANA', 'Yuk bayar pakai DANA, diskon Rp 10.000'), isNull);
    });

    test('OTP', () {
      expect(parse(seabank, 'Kode OTP', 'Kode OTP Anda 123456 untuk transfer Rp 50.000'), isNull);
    });

    test('tanpa nominal', () {
      expect(parse(seabank, 'Info', 'Transfer masuk berhasil'), isNull);
    });

    test('tanpa kata kunci transaksi', () {
      expect(parse(seabank, 'Info', 'Saldo Anda Rp 1.000.000'), isNull);
    });
  });

  group('TransactionModel', () {
    test('sumber dan deskripsi dari judul lama', () {
      final tx = TransactionModel(
        title: 'SeaBank Masuk',
        amount: 1,
        type: TxType.income,
        createdAt: DateTime(2026),
      );
      expect(tx.source, TxSource.seabank);
      expect(tx.description, 'Masuk');
    });

    test('judul manual tanpa prefix', () {
      final tx = TransactionModel(
        title: 'Makan siang',
        amount: 1,
        type: TxType.expense,
        createdAt: DateTime(2026),
      );
      expect(tx.source, TxSource.manual);
      expect(tx.description, 'Makan siang');
    });

    test('fromMap toleran terhadap tipe', () {
      final tx = TransactionModel.fromMap({
        'id': 7,
        'title': 'DANA · Dari RINA',
        'amount': '50000',
        'type': 'income',
        'created_at': '2026-07-11T03:00:00+00:00',
      });
      expect(tx.id, 7);
      expect(tx.amount, 50000);
      expect(tx.isIncome, isTrue);
      expect(tx.createdAt.isUtc, isTrue);
    });
  });
}
