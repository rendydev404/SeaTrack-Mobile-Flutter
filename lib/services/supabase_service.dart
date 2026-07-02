import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  }

  static Future<void> insertTransaction(TransactionModel transaction) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('transactions').insert(transaction.toMap());
      debugPrint('Transaction synced to Supabase successfully.');
    } catch (e) {
      debugPrint('Error syncing to Supabase: $e');
    }
  }
}
