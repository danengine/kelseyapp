import 'package:flutter/material.dart';

import 'admin_bookings_tab.dart';
import 'bookings_tab.dart';
import 'home_tab.dart';
import 'kelsey_chat_screen.dart';
import 'kelsey_brand.dart';
import 'login_screen.dart';
import 'services/auth_session.dart';
import 'services/auth_storage.dart';
import 'services/bookings_cache.dart';

import 'facebook_posts_screen.dart';
import 'rewards_screen.dart';

/// Logged-in area with bottom navigation: Home, Bookings, [Manage], Profile.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final GlobalKey<BookingsTabState> _bookingsTabKey = GlobalKey<BookingsTabState>();
  final GlobalKey<AdminBookingsTabState> _adminBookingsTabKey = GlobalKey<AdminBookingsTabState>();

  bool get _isAdmin => AuthSession.profile?.isAdmin ?? false;

  int get _profileIndex => _isAdmin ? 3 : 2;

  int get _bookingsIndex => 1;

  int? get _manageIndex => _isAdmin ? 2 : null;

  void _onTabSelected(int index) {
    setState(() => _index = index);
    if (index == _bookingsIndex) {
      _bookingsTabKey.currentState?.reload();
    } else if (_manageIndex != null && index == _manageIndex) {
      _adminBookingsTabKey.currentState?.reload();
    }
  }

  Widget _pageAt(int index) {
    if (index == 0) return const HomeTab();
    if (index == _bookingsIndex) return BookingsTab(key: _bookingsTabKey);
    if (_isAdmin && index == 2) return AdminBookingsTab(key: _adminBookingsTabKey);
    return const _ProfileTab();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeIndex = _index.clamp(0, _profileIndex);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(safeIndex),
          child: _pageAt(safeIndex),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: KelseyChatLauncherButton(
          onTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const KelseyChatScreen()),
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _onTabSelected,
        indicatorColor: scheme.primaryContainer,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Bookings',
          ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings_rounded),
              label: 'Manage',
            ),
          const NavigationDestination(
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
    final isAdmin = profile?.isAdmin ?? false;
    final canAccessRewards = profile?.canAccessRewards ?? false;

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
              ProfileChatEntryCard(
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const KelseyChatScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Account',
                style: textTheme.labelLarge?.copyWith(
                  color: KelseyColors.cardMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              if (isAdmin) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2)),
                  title: const Text('Facebook posts'),
                  trailing: Icon(Icons.chevron_right_rounded, color: KelseyColors.cardMuted),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const FacebookPostsScreen()),
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.card_giftcard_rounded, color: KelseyColors.tealButton),
                title: const Text('Rewards'),
                subtitle: canAccessRewards
                    ? null
                    : Text(
                        'Agents only',
                        style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                      ),
                trailing: Icon(Icons.chevron_right_rounded, color: KelseyColors.cardMuted),
                onTap: () {
                  if (!canAccessRewards) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Rewards Hub is available for agents and admins.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(builder: (_) => const RewardsScreen()),
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
