import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/sources.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_detail_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  TxType? _type;
  TxSource? _source;
  String _query = '';

  /// Tetap hidup saat digeser ke halaman lain, supaya kata kunci pencarian dan
  /// filter tidak hilang begitu pengguna mengintip halaman sebelah.
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TransactionModel> _filter(List<TransactionModel> all) {
    if (_type == null && _source == null && _query.isEmpty) return all;
    final q = _query.toLowerCase();
    return [
      for (final t in all)
        if ((_type == null || t.type == _type) &&
            (_source == null || t.source == _source) &&
            (q.isEmpty || t.title.toLowerCase().contains(q) || Fmt.idr(t.amount).contains(q)))
          t,
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final all = context.select<TransactionProvider, List<TransactionModel>>((p) => p.items);
    final loading = context.select<TransactionProvider, bool>((p) => p.loading && p.isEmpty);
    final items = _filter(all);
    final rows = _group(items);

    return RefreshIndicator(
      onRefresh: () => context.read<TransactionProvider>().refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Transaksi'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '${items.length} data',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari keterangan atau nominal',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip('Semua', _type == null && _source == null, () => setState(() {
                        _type = null;
                        _source = null;
                      })),
                  _chip('Masuk', _type == TxType.income, () => setState(() => _type = _type == TxType.income ? null : TxType.income),
                      color: AppColors.income),
                  _chip('Keluar', _type == TxType.expense, () => setState(() => _type = _type == TxType.expense ? null : TxType.expense),
                      color: AppColors.expense),
                  for (final s in TxSource.values)
                    _chip(s.label, _source == s, () => setState(() => _source = _source == s ? null : s), color: s.color),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (rows.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: all.isEmpty ? Icons.receipt_long_rounded : Icons.search_off_rounded,
                title: all.isEmpty ? 'Belum ada transaksi' : 'Tidak ada yang cocok',
                message: all.isEmpty
                    ? 'Transaksi dari notifikasi bank akan muncul di sini.'
                    : 'Coba ubah kata kunci atau filter.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  if (row is _Header) return _DayHeader(row: row);
                  final item = row as _Item;
                  return _GroupedTile(tx: item.tx, first: item.first, last: item.last);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: c.withValues(alpha: 0.16),
        backgroundColor: scheme.surface,
        labelStyle: TextStyle(color: selected ? c : scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        side: BorderSide(color: selected ? Colors.transparent : scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }

  static List<_Row> _group(List<TransactionModel> items) {
    final rows = <_Row>[];
    DateTime? current;
    var start = -1;
    double dayIn = 0, dayOut = 0;

    void closeGroup() {
      if (start < 0) return;
      rows[start] = _Header(current!, dayIn, dayOut);
      (rows.last as _Item).last = true;
    }

    for (final tx in items) {
      final l = tx.createdAt.toLocal();
      final day = DateTime(l.year, l.month, l.day);
      if (current != day) {
        closeGroup();
        current = day;
        dayIn = 0;
        dayOut = 0;
        start = rows.length;
        rows.add(_Header(day, 0, 0));
        rows.add(_Item(tx, first: true));
      } else {
        rows.add(_Item(tx));
      }
      if (tx.isIncome) {
        dayIn += tx.amount;
      } else {
        dayOut += tx.amount;
      }
    }
    closeGroup();
    return rows;
  }
}

sealed class _Row {}

class _Header extends _Row {
  _Header(this.day, this.income, this.expense);
  final DateTime day;
  final double income;
  final double expense;
}

class _Item extends _Row {
  _Item(this.tx, {this.first = false});
  final TransactionModel tx;
  final bool first;
  bool last = false;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.row});
  final _Header row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final net = row.income - row.expense;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Fmt.dayHeader(row.day),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
            ),
          ),
          Text(
            Fmt.signed(net.abs(), net >= 0),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: net >= 0 ? AppColors.income : AppColors.expense,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris transaksi di dalam kelompok harian.
///
/// Tidak memakai geser-untuk-hapus: gerakan mendatar di daftar ini sudah
/// dipakai untuk berpindah halaman. Hapus cepat lewat tekan-tahan, atau lewat
/// lembar detail setelah diketuk.
class _GroupedTile extends StatelessWidget {
  const _GroupedTile({required this.tx, required this.first, required this.last});
  final TransactionModel tx;
  final bool first;
  final bool last;

  Future<void> _delete(BuildContext context) async {
    final provider = context.read<TransactionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDelete(context)) return;
    try {
      await provider.remove(tx);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Gagal menghapus. Coba lagi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(first ? 18 : 0),
        bottom: Radius.circular(last ? 18 : 0),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: last
              ? null
              : Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
        ),
        child: TransactionTile(
          tx: tx,
          onTap: () => showTransactionDetail(context, tx),
          onLongPress: () => _delete(context),
        ),
      ),
    );
  }
}
