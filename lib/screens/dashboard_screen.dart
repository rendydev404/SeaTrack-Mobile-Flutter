import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../providers/listener_controller.dart';
import '../providers/transaction_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/permission_card.dart';
import '../widgets/section_header.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/update_banner.dart';
import '../widgets/weekly_chart.dart';
import 'transaction_detail_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _monthOnly = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        final l = context.read<ListenerController>();
        await context.read<TransactionProvider>().refresh();
        await l.sweepActive();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverAppBar(
            pinned: true,
            title: Text('SeaTrack'),
            actions: [_StatusPill(), SizedBox(width: 12)],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList.list(
              children: [
                const UpdateBanner(),
                const _PermissionSection(),
                const _ErrorBanner(),
                _BalanceCard(
                  monthOnly: _monthOnly,
                  onToggle: (v) => setState(() => _monthOnly = v),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Selector<TransactionProvider, List<DayStat>>(
                      selector: (_, p) => p.stats.week,
                      builder: (_, week, __) => WeeklyChart(days: week),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SectionHeader(
                  title: 'Transaksi Terbaru',
                  actionLabel: 'Lihat semua',
                  onAction: widget.onViewAll,
                ),
                const SizedBox(height: 8),
                const _RecentList(),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tarik ke bawah untuk menyegarkan',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    final active = context.select<ListenerController, bool>((l) => l.listening);
    final ready = context.select<ListenerController, bool>((l) => l.ready);
    if (!ready) return const SizedBox.shrink();
    final color = active ? AppColors.income : Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            active ? 'Listener aktif' : 'Listener nonaktif',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _PermissionSection extends StatelessWidget {
  const _PermissionSection();

  @override
  Widget build(BuildContext context) {
    final l = context.watch<ListenerController>();
    if (!l.ready) return const SizedBox.shrink();
    if (l.notificationGranted && l.batteryIgnored) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: l.notificationGranted
          ? PermissionCard(
              icon: Icons.battery_saver_rounded,
              title: 'Izinkan berjalan di latar belakang',
              message:
                  'Agar notifikasi transaksi tetap terbaca saat layar mati, kecualikan SeaTrack dari optimasi baterai.',
              buttonLabel: 'Buka Pengaturan Baterai',
              tone: PermissionTone.secondary,
              onPressed: l.requestBatteryExemption,
            )
          : PermissionCard(
              icon: Icons.notifications_active_rounded,
              title: 'Aktifkan akses notifikasi',
              message:
                  'SeaTrack membaca notifikasi SeaBank, DANA, dan GoPay untuk mencatat transaksi secara otomatis. Tidak ada data lain yang dibaca.',
              buttonLabel: 'Berikan Akses',
              onPressed: l.requestNotificationAccess,
            ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner();

  @override
  Widget build(BuildContext context) {
    final error = context.select<TransactionProvider, String?>((p) => p.error);
    if (error == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(error, style: TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.monthOnly, required this.onToggle});

  final bool monthOnly;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final stats = context.select<TransactionProvider, TxStats>((p) => p.stats);
    final loading = context.select<TransactionProvider, bool>((p) => p.loading && p.isEmpty);
    final scheme = Theme.of(context).colorScheme;
    final income = monthOnly ? stats.monthIncome : stats.income;
    final expense = monthOnly ? stats.monthExpense : stats.expense;
    final balance = income - expense;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthOnly ? 'Saldo bersih · ${Fmt.month(DateTime.now())}' : 'Saldo bersih · Semua waktu',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              _PeriodToggle(monthOnly: monthOnly, onToggle: onToggle),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                ),
              ),
            )
          else
            Text(
              Fmt.idr(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Mini(label: 'Masuk', value: income, icon: Icons.south_west_rounded)),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(child: _Mini(label: 'Keluar', value: expense, icon: Icons.north_east_rounded, alignEnd: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.monthOnly, required this.onToggle});
  final bool monthOnly;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool value) {
      final selected = monthOnly == value;
      return GestureDetector(
        onTap: () => onToggle(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.seed : Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('Bulan ini', true), seg('Semua', false)]),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.icon, this.alignEnd = false});
  final String label;
  final double value;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: alignEnd ? 16 : 0, right: alignEnd ? 0 : 16),
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            Fmt.idr(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList();

  @override
  Widget build(BuildContext context) {
    final items = context.select<TransactionProvider, List<TransactionModel>>(
      (p) => p.items.length > 5 ? p.items.sublist(0, 5) : p.items,
    );
    final loading = context.select<TransactionProvider, bool>((p) => p.loading && p.isEmpty);
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (items.isEmpty) {
      return const Card(
        child: EmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Belum ada transaksi',
          message: 'Transaksi akan tercatat otomatis saat notifikasi bank masuk, atau catat manual lewat tombol +.',
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 74),
            TransactionTile(
              tx: items[i],
              showDate: true,
              onTap: () => showTransactionDetail(context, items[i]),
            ),
          ],
        ],
      ),
    );
  }
}
