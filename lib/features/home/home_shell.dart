import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../kelola_kelas/kelola_kelas_screen.dart';
import '../profil/profil_screen.dart';
import '../rekap/rekap_screen.dart';
import 'home_screen.dart';

class _Tab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
  const _Tab(this.label, this.icon, this.activeIcon, this.screen);
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Tab> _tabsFor(UserModel user) {
    final isDosen = user.role == UserRole.dosen;
    return [
      const _Tab('Home', Icons.home_outlined, Icons.home, HomeScreen()),
      isDosen
          ? const _Tab('Kelas', Icons.school_outlined, Icons.school, KelolaKelasScreen())
          : _Tab('Riwayat', Icons.bar_chart_outlined, Icons.bar_chart, RekapScreen()),
      const _Tab('Profil', Icons.person_outline, Icons.person, ProfilScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) return const SizedBox.shrink();
    final tabs = _tabsFor(user);
    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      appBar: AppBar(title: Text(tabs[_index].label)),
      body: IndexedStack(
        index: _index,
        children: [for (final t in tabs) t.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon, color: AppTheme.primary),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
