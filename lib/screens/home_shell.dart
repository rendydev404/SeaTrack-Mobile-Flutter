import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'transaction_form_sheet.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _pager = PageController();
  int _index = 0;

  /// Seberapa dekat halaman Pengaturan, 0 sampai 1. Dipakai untuk menyembunyikan
  /// tombol catat secara bertahap saat jari masih menggeser, bukan mengejutkan
  /// pengguna dengan hilang mendadak begitu halaman berganti.
  double _settingsProximity = 0;

  @override
  void initState() {
    super.initState();
    _pager.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_pager.hasClients || _pager.position.hasPixels == false) return;
    final page = _pager.page ?? _index.toDouble();
    final next = (page - 1).clamp(0.0, 1.0);
    if ((next - _settingsProximity).abs() > 0.01) {
      setState(() => _settingsProximity = next);
    }
  }

  @override
  void dispose() {
    _pager.removeListener(_onScroll);
    _pager.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i == _index) return;
    _pager.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fabScale = 1 - _settingsProximity;
    return Scaffold(
      // PageView, bukan IndexedStack: halaman bisa digeser dengan jari dan
      // halaman tetangga ikut bergerak mengikuti jari selagi digeser.
      body: PageView(
        controller: _pager,
        onPageChanged: (i) => setState(() => _index = i),
        children: [
          DashboardScreen(onViewAll: () => _goTo(1)),
          const TransactionsScreen(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: fabScale <= 0.01
          ? null
          : Transform.scale(
              scale: fabScale,
              child: Opacity(
                opacity: fabScale.clamp(0.0, 1.0),
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final saved = await showTransactionForm(context);
                    if (saved == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaksi tersimpan')),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Catat'),
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
