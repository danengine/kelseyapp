import 'package:flutter/material.dart';

import 'bookings_tab.dart';
import 'home_tab.dart';
import 'kelsey_brand.dart';
import 'login_screen.dart';
import 'services/auth_session.dart';
import 'services/auth_storage.dart';
import 'services/bookings_cache.dart';

/// Logged-in area with bottom navigation: Home, Bookings, Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final GlobalKey<BookingsTabState> _bookingsTabKey = GlobalKey<BookingsTabState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeTab(),
      BookingsTab(key: _bookingsTabKey),
      const _ProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _pages[_index],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 1) {
            _bookingsTabKey.currentState?.reload();
          }
        },
        indicatorColor: scheme.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final profile = AuthSession.profile;
    final fullName = profile?.fullName ?? 'Guest';
    final role = profile?.roleLabel ?? 'Guest';
    final email = profile?.email ?? '';
    final initial = profile?.avatarInitial ?? '?';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          surfaceTintColor: Colors.transparent,
          backgroundColor: scheme.surface,
          title: const Text('Profile'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      initial,
                      style: textTheme.headlineMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role,
                          style: textTheme.bodyMedium?.copyWith(
                            color: KelseyColors.tealButton,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: textTheme.bodyMedium?.copyWith(color: KelseyColors.cardMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.card_giftcard_rounded, color: KelseyColors.tealButton),
                title: const Text('Rewards'),
                trailing: Text(
                  'Coming soon',
                  style: textTheme.labelMedium?.copyWith(
                    color: KelseyColors.cardMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rewards — coming soon.')),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Log out'),
                onTap: () async {
                  await AuthStorage.clearSession();
                  await BookingsCache.clear();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil<void>(
                    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
