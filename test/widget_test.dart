import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:seatrack/core/theme.dart';
import 'package:seatrack/models/transaction.dart';
import 'package:seatrack/widgets/transaction_tile.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('TransactionTile menampilkan sumber, keterangan, dan nominal', (tester) async {
    final tx = TransactionModel(
      title: 'SeaBank · Dari BUDI',
      amount: 150000,
      type: TxType.income,
      createdAt: DateTime(2026, 7, 11, 9, 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TransactionTile(tx: tx)),
      ),
    );
    expect(find.text('Dari BUDI'), findsOneWidget);
    expect(find.textContaining('SeaBank'), findsOneWidget);
    expect(find.textContaining('150.000'), findsOneWidget);
  });
}
