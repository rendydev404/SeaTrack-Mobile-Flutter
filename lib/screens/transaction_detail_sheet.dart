import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../widgets/source_avatar.dart';
import 'transaction_form_sheet.dart';

Future<void> showTransactionDetail(BuildContext context, TransactionModel tx) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (_) => _DetailSheet(tx: tx),
  );
}

/// Konfirmasi hapus. Mengembalikan `true` bila pengguna setuju.
Future<bool> confirmDelete(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus transaksi?'),
      content: const Text('Data akan dihapus permanen dari perangkat ini.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.expense,
            minimumSize: const Size(0, 40),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.tx});
  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tx.isIncome ? AppColors.income : AppColors.expense;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SourceAvatar(source: tx.source, type: tx.type, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.source.label} · ${tx.type.label}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            Fmt.signed(tx.amount, tx.isIncome),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(Fmt.full(tx.createdAt), style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await showTransactionForm(context, existing: tx);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Ubah'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.expense.withValues(alpha: 0.12),
                    foregroundColor: AppColors.expense,
                  ),
                  onPressed: () async {
                    final provider = context.read<TransactionProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    if (!await confirmDelete(context)) return;
                    try {
                      await provider.remove(tx);
                      nav.pop();
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Gagal menghapus. Coba lagi.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Hapus'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
