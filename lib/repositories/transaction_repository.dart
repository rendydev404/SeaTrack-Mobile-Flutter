import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class TransactionRepository {
  final _supabase = Supabase.instance.client;
  final String _tableName = 'transactions';

  Future<void> insertTransaction(TransactionModel transaction) async {
    try {
      await _supabase.from(_tableName).insert(transaction.toMap());
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      rethrow;
    }
  }

  Future<List<TransactionModel>> getTransactions() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      
      return response.map((data) => TransactionModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      rethrow;
    }
  }

  Stream<List<TransactionModel>> getTransactionsStream() {
    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((item) => TransactionModel.fromMap(item)).toList());
  }
}
