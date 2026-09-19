import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/sources.dart';
import '../core/theme.dart';
import '../providers/activity_log.dart';
import '../providers/listener_controller.dart';
import '../providers/transaction_provider.dart';
import '../providers/update_controller.dart';
import '../services/database_service.dart';
import '../services/update_service.dart';
import 'activity_log_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<ListenerController>();
    final count = context.select<TransactionProvider, int>((p) => p.items.length);
    final latest = context.select<ActivityLog, LogEntry?>((a) => a.latest);
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(pinned: true, title: Text('Pengaturan')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          sliver: SliverList.list(
            children: [
              _Group(
                title: 'Izin',
                children: [
                  _StatusTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Akses notifikasi',
                    subtitle: l.notificationGranted
                        ? 'Aktif. Notifikasi bank dibaca otomatis.'
                        : 'Diperlukan untuk mencatat transaksi.',
                    ok: l.notificationGranted,
                    onTap: l.notificationGranted ? null : l.requestNotificationAccess,
                  ),
                  _StatusTile(
                    icon: Icons.battery_charging_full_outlined,
                    title: 'Optimasi baterai',
                    subtitle: l.batteryIgnored
                        ? 'Dikecualikan. Listener tidak dimatikan sistem.'
                        : 'Kecualikan agar tetap berjalan di latar belakang.',
                    ok: l.batteryIgnored,
                    onTap: l.batteryIgnored ? null : l.requestBatteryExemption,
                  ),
                ],
              ),
              _Group(
                title: 'Sumber yang didukung',
                children: [
                  for (final s in TxSource.supported)
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            s.label.substring(0, 1),
                            style: TextStyle(color: s.color, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Transfer masuk, keluar, QRIS, top up'),
                    ),
                ],
              ),
              _Group(
                title: 'Data',
                children: [
                  ListTile(
                    leading: Icon(Icons.phone_android_rounded, color: scheme.onSurfaceVariant),
                    title: const Text('Penyimpanan'),
                    subtitle: const Text(
                      'Semua transaksi disimpan di database SQLite pada perangkat ini. Tidak ada data yang dikirim ke server.',
                    ),
                    isThreeLine: true,
                  ),
                  ListTile(
                    leading: Icon(Icons.storage_outlined, color: scheme.onSurfaceVariant),
                    title: const Text('Total transaksi'),
                    subtitle: const _DatabaseSize(),
                    trailing: Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  ListTile(
                    leading: Icon(Icons.refresh_rounded, color: scheme.onSurfaceVariant),
                    title: const Text('Muat ulang'),
                    subtitle: const Text('Baca ulang database dan periksa notifikasi aktif'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await context.read<TransactionProvider>().refresh();
                      await l.sweepActive();
                      messenger.showSnackBar(const SnackBar(content: Text('Data diperbarui')));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.history_rounded, color: scheme.onSurfaceVariant),
                    title: const Text('Log aktivitas'),
                    subtitle: Text(
                      latest == null ? 'Belum ada aktivitas' : '${Fmt.time(latest.time)} · ${latest.message}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
                    title: const Text('Hapus semua data', style: TextStyle(color: AppColors.expense)),
                    subtitle: const Text('Kosongkan database di perangkat ini'),
                    enabled: count > 0,
                    onTap: () => _confirmWipe(context, count),
                  ),
                ],
              ),
              const _UpdateGroup(),
              _Group(
                title: 'Tentang',
                children: [
                  const _VersionTile(),
                  ListTile(
                    leading: Icon(Icons.lock_outline_rounded, color: scheme.onSurfaceVariant),
                    title: const Text('Privasi'),
                    subtitle: const Text(
                      'Hanya notifikasi dari aplikasi yang didukung yang diproses. Notifikasi lain diabaikan, dan tidak ada koneksi internet yang dipakai untuk data transaksi.',
                    ),
                    isThreeLine: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmWipe(BuildContext context, int count) async {
    final provider = context.read<TransactionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua data?'),
        content: Text(
          '$count transaksi akan dihapus permanen dari perangkat ini. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await provider.removeAll();
      messenger.showSnackBar(const SnackBar(content: Text('Semua data dihapus')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Gagal menghapus data')));
    }
  }
}

/// Bagian pembaruan. Disembunyikan bila URL manifest tidak diisi saat build.
class _UpdateGroup extends StatelessWidget {
  const _UpdateGroup();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UpdateController>();
    if (!c.enabled) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final version = c.release?.versionName;

    final (String subtitle, Widget? trailing) = switch (c.state) {
      UpdateState.checking => ('Memeriksa versi terbaru…', null),
      UpdateState.available => ('Versi $version tersedia', null),
      UpdateState.downloading => (
          [
            'Mengunduh versi $version',
            if (c.status.payloadLabel != null) c.status.payloadLabel!,
            '${c.status.progress}%',
          ].join(' · '),
          null,
        ),
      UpdateState.ready => (
          'Versi $version siap dipasang',
          TextButton(onPressed: c.install, child: const Text('Pasang')),
        ),
      UpdateState.installing => ('Memasang versi $version…', null),
      UpdateState.needsPermission => (
          'Butuh izin memasang aplikasi',
          TextButton(onPressed: c.grantAndInstall, child: const Text('Izinkan')),
        ),
      UpdateState.failed => (
          c.status.error ?? 'Pembaruan gagal',
          TextButton(onPressed: c.checkNow, child: const Text('Ulangi')),
        ),
      UpdateState.idle => (
          'Sudah versi terbaru',
          TextButton(onPressed: c.checkNow, child: const Text('Periksa')),
        ),
    };

    return _Group(
      title: 'Pembaruan',
      children: [
        ListTile(
          leading: Icon(
            c.state == UpdateState.failed
                ? Icons.error_outline_rounded
                : Icons.system_update_rounded,
            color: c.state == UpdateState.failed
                ? AppColors.expense
                : scheme.onSurfaceVariant,
          ),
          title: const Text('Pembaruan otomatis',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
          trailing: c.state.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : trailing,
        ),
        ListTile(
          leading: Icon(Icons.open_in_new_rounded, color: scheme.onSurfaceVariant),
          title: const Text('Buka sendiri setelah pembaruan'),
          subtitle: const Text(
            'Butuh izin tampil di atas aplikasi lain. Tanpa ini, pembaruan tetap terpasang tetapi aplikasi harus dibuka manual.',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: c.requestRelaunchPermission,
        ),
      ],
    );
  }
}

/// Nama versi diambil dari paket terpasang, bukan ditulis tangan.
class _VersionTile extends StatelessWidget {
  const _VersionTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final version = context.select<UpdateController, String>(
      (c) => c.status.currentVersionName,
    );
    return ListTile(
      leading: Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
      title: const Text('SeaTrack'),
      subtitle: Text('Versi $version · Pencatat transaksi otomatis'),
    );
  }
}

/// Ukuran file database dibaca sekali saat widget dibangun.
class _DatabaseSize extends StatelessWidget {
  const _DatabaseSize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: DatabaseService.sizeInBytes(),
      builder: (context, snap) {
        final bytes = snap.data ?? 0;
        final text = bytes <= 0
            ? 'Database lokal'
            : 'Database lokal · ${(bytes / 1024).toStringAsFixed(0)} KB';
        return Text(text);
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(indent: 56),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: onTap == null
          ? _Dot(ok: ok)
          : FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: onTap,
              child: const Text('Atur'),
            ),
      onTap: onTap,
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.ok});
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.income : Theme.of(context).colorScheme.outline;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
