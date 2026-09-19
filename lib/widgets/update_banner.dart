import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/update_controller.dart';
import '../services/update_service.dart';

/// Membuka layar izin pasang milik Android. Sebagian ROM menyembunyikan layar
/// itu, jadi kegagalannya disampaikan sebagai saran pengaturan manual.
Future<void> grantInstallPermission(
  BuildContext context,
  UpdateController controller,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await controller.grantAndInstall();
  if (opened) return;
  messenger.showSnackBar(
    const SnackBar(
      duration: Duration(seconds: 6),
      content: Text(
        'Buka Pengaturan Android, Aplikasi, SeaTrack, lalu aktifkan "Pasang aplikasi tidak dikenal".',
      ),
    ),
  );
}

/// Pita status pembaruan di dashboard. Menghilang sendiri saat tidak ada apa-apa,
/// karena seluruh alur berjalan otomatis di latar belakang.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<UpdateController>();
    if (!c.hasBanner) return const SizedBox.shrink();

    final installed = c.status.justInstalledVersion;
    if (installed != null) {
      return _Shell(
        icon: Icons.check_circle_rounded,
        color: AppColors.income,
        title: 'SeaTrack diperbarui ke versi $installed',
        subtitle: 'Pembaruan berhasil dipasang.',
        trailing: TextButton(
          onPressed: c.dismissInstalledNotice,
          child: const Text('Tutup'),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final version = c.release?.versionName ?? '';
    final payload = c.status.payloadLabel;

    return switch (c.state) {
      UpdateState.available => _Shell(
          icon: Icons.system_update_rounded,
          color: scheme.primary,
          title: 'Versi $version tersedia',
          subtitle: payload == null
              ? 'Menyiapkan unduhan.'
              : 'Menyiapkan unduhan, $payload.',
          bar: true,
        ),
      UpdateState.downloading => _Shell(
          icon: Icons.downloading_rounded,
          color: scheme.primary,
          title: 'Mengunduh versi $version',
          subtitle: payload == null
              ? '${c.status.progress}% selesai. Berjalan di latar belakang.'
              : '$payload · ${c.status.progress}% selesai.',
          bar: true,
          value: c.status.progress / 100,
        ),
      UpdateState.ready => _Shell(
          icon: Icons.install_mobile_rounded,
          color: scheme.primary,
          title: 'Versi $version siap dipasang',
          subtitle: 'Pemasangan berjalan otomatis sebentar lagi.',
          trailing: TextButton(
            onPressed: c.install,
            child: const Text('Pasang'),
          ),
        ),
      UpdateState.installing => _Shell(
          icon: Icons.settings_backup_restore_rounded,
          color: scheme.primary,
          title: 'Memasang versi $version',
          subtitle: 'Aplikasi akan terbuka kembali sendiri.',
          bar: true,
        ),
      UpdateState.needsPermission => _Shell(
          icon: Icons.lock_open_rounded,
          color: scheme.tertiary,
          title: 'Butuh izin memasang',
          subtitle:
              'Izinkan SeaTrack memasang aplikasi agar pembaruan bisa selesai sendiri.',
          trailing: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () => grantInstallPermission(context, c),
            child: const Text('Izinkan'),
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.bar = false,
    this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget? trailing;

  /// Menampilkan bilah kemajuan di bawah teks.
  final bool bar;

  /// Panjang bilah 0..1. `null` berarti kemajuan belum terukur.
  final double? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            if (bar) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor: color.withValues(alpha: 0.18),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
