import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

class DayStat {
  final DateTime day;
  final double income;
  final double expense;
  const DayStat(this.day, this.income, this.expense);
}

/// Ringkasan yang dihitung sekali setiap daftar transaksi berubah.
class TxStats {
  final double income;
  final double expense;
  final double monthIncome;
  final double monthExpense;
  final int monthCount;
  final List<DayStat> week;

  const TxStats({
    this.income = 0,
    this.expense = 0,
    this.monthIncome = 0,
    this.monthExpense = 0,
    this.monthCount = 0,
    this.week = const [],
  });

  double get balance => income - expense;
  double get monthBalance => monthIncome - monthExpense;

  static TxStats compute(List<TransactionModel> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));
    final weekIn = List<double>.filled(7, 0);
    final weekOut = List<double>.filled(7, 0);

    double income = 0, expense = 0, mIn = 0, mOut = 0;
    int mCount = 0;

    for (final tx in items) {
      final local = tx.createdAt.toLocal();
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        expense += tx.amount;
      }
      if (local.year == now.year && local.month == now.month) {
        mCount++;
        if (tx.isIncome) {
          mIn += tx.amount;
        } else {
          mOut += tx.amount;
        }
      }
      final day = DateTime(local.year, local.month, local.day);
      final idx = day.difference(weekStart).inDays;
      if (idx >= 0 && idx < 7) {
        if (tx.isIncome) {
          weekIn[idx] += tx.amount;
        } else {
          weekOut[idx] += tx.amount;
        }
      }
    }

    return TxStats(
      income: income,
      expense: expense,
      monthIncome: mIn,
      monthExpense: mOut,
      monthCount: mCount,
      week: List.generate(
        7,
        (i) => DayStat(weekStart.add(Duration(days: i)), weekIn[i], weekOut[i]),
        growable: false,
      ),
    );
  }
}

class TransactionProvider extends ChangeNotifier {
  TransactionProvider(this._repo);

  final TransactionRepository _repo;

  List<TransactionModel> _items = const [];
  TxStats _stats = const TxStats();
  bool _loading = true;
  String? _error;

  List<TransactionModel> get items => _items;
  TxStats get stats => _stats;
  bool get loading => _loading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty;

  Future<void> refresh() async {
    _error = null;
    notifyListeners();
    try {
      _set(await _repo.fetchAll());
    } catch (e) {
      _error = 'Gagal membaca database lokal.';
      debugPrint('Gagal memuat transaksi: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Dipakai listener notifikasi untuk mencegah duplikat.
  Future<bool> existsAt(DateTime createdAt) => _repo.existsAt(createdAt);

  Future<TransactionModel> add(TransactionModel tx) async {
    final saved = await _repo.insert(tx);
    _set([saved, ..._items]);
    return saved;
  }

  Future<void> edit(TransactionModel tx) async {
    await _repo.update(tx);
    _set([for (final t in _items) t.id == tx.id ? tx : t]);
  }

  Future<void> remove(TransactionModel tx) async {
    final id = tx.id;
    if (id == null) return;
    await _repo.delete(id);
    _set([for (final t in _items) if (t.id != id) t]);
  }

  Future<void> removeAll() async {
    await _repo.deleteAll();
    _set(const []);
  }

  void _set(List<TransactionModel> rows) {
    final sorted = [...rows]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _items = List.unmodifiable(sorted);
    _stats = TxStats.compute(_items);
    _error = null;
    notifyListeners();
  }
}
