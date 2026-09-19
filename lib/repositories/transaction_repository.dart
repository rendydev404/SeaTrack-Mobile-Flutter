import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';

class TransactionRepository {
  const TransactionRepository();

  Database get _db => DatabaseService.instance;
  static const _table = DatabaseService.table;

  Future<List<TransactionModel>> fetchAll() async {
    final rows = await _db.query(_table, orderBy: 'created_at DESC, id DESC');
    return rows.map(TransactionModel.fromMap).toList(growable: false);
  }

  Future<TransactionModel> insert(TransactionModel tx) async {
    final id = await _db.insert(_table, tx.toMap());
    return tx.copyWith(id: id);
  }

  Future<void> update(TransactionModel tx) async {
    final id = tx.id;
    if (id == null) throw ArgumentError('Transaksi belum memiliki id');
    await _db.update(_table, tx.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    await _db.delete(_table);
  }

  /// Cek duplikat langsung di database, tanpa bergantung pada daftar di memori.
  Future<bool> existsAt(DateTime createdAt) async {
    final rows = await _db.query(
      _table,
      columns: ['id'],
      where: 'created_at = ?',
      whereArgs: [createdAt.toUtc().toIso8601String()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
