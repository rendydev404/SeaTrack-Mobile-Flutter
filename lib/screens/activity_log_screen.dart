import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../providers/activity_log.dart';
import '../widgets/empty_state.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final log = context.watch<ActivityLog>();
    final entries = log.entries;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Aktivitas'),
        actions: [
          if (entries.isNotEmpty)
            TextButton(onPressed: log.clear, child: const Text('Bersihkan')),
          const SizedBox(width: 4),
        ],
      ),
      body: entries.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'Belum ada aktivitas',
              message: 'Setiap notifikasi yang diproses akan tercatat di sini selama aplikasi berjalan.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final e = entries[i];
                final color = switch (e.level) {
                  LogLevel.success => AppColors.income,
                  LogLevel.warning => Colors.orange.shade700,
                  LogLevel.error => AppColors.expense,
                  LogLevel.info => scheme.onSurfaceVariant,
                };
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.message, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        Fmt.time(e.time),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
