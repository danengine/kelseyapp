import 'package:flutter/material.dart';

import 'admin_agents_tab.dart';
import 'admin_bookings_tab.dart';
import 'booking_models.dart';
import 'kelsey_brand.dart';
import 'models/admin_agent_item.dart';
import 'services/admin_agents_service.dart';
import 'services/admin_bookings_service.dart';
import 'services/auth_service.dart';
import 'utils/currency_utils.dart';

/// Admin manage hub — overview, bookings, and agents (matches web admin panel).
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  AdminDashboardTabState createState() => AdminDashboardTabState();
}

class AdminDashboardTabState extends State<AdminDashboardTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _bookingsKey = GlobalKey<AdminBookingsTabState>();
  final _agentsKey = GlobalKey<AdminAgentsTabState>();
  final _overviewKey = GlobalKey<_AdminOverviewPaneState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    await _overviewKey.currentState?.reload();
    _bookingsKey.currentState?.reload();
    _agentsKey.currentState?.reload();
  }

  void _goToTab(int index) {
    _tabController.animateTo(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KelseyColors.adminSurface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _AdminHubCard(
                onTabSelected: _goToTab,
                tabController: _tabController,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AdminOverviewPane(
                    key: _overviewKey,
                    onOpenBookings: () => _goToTab(1),
                    onOpenAgents: () => _goToTab(2),
                  ),
                  AdminBookingsTab(key: _bookingsKey, embedded: true),
                  AdminAgentsTab(key: _agentsKey, embedded: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHubCard extends StatelessWidget {
  const _AdminHubCard({
    required this.onTabSelected,
    required this.tabController,
  });

  final ValueChanged<int> onTabSelected;
  final TabController tabController;

  static const _tabs = ['Overview', 'Bookings', 'Agents'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: KelseyColors.adminBadgeRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: KelseyColors.adminBadgeRed.withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'AD',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Hub',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: KelseyColors.adminBadgeRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: KelseyColors.adminBadgeRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF9FAFB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                return Row(
                  children: List.generate(_tabs.length, (index) {
                    final selected = tabController.index == index;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                        child: Material(
                          color: selected ? KelseyColors.adminTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          elevation: selected ? 2 : 0,
                          shadowColor: KelseyColors.adminTeal.withValues(alpha: 0.2),
                          child: InkWell(
                            onTap: () => onTabSelected(index),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Text(
                                _tabs[index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOverviewPane extends StatefulWidget {
  const _AdminOverviewPane({
    super.key,
    required this.onOpenBookings,
    required this.onOpenAgents,
  });

  final VoidCallback onOpenBookings;
  final VoidCallback onOpenAgents;

  @override
  State<_AdminOverviewPane> createState() => _AdminOverviewPaneState();
}

class _AdminOverviewPaneState extends State<_AdminOverviewPane> {
  final _bookingsService = const AdminBookingsService();
  final _agentsService = const AdminAgentsService();

  bool _loading = true;
  String? _error;
  int _totalBookings = 0;
  int _pendingBookings = 0;
  AdminAnalyticsSummary? _analytics;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookings = await _bookingsService.fetchAllBookings();
      final analytics = await _agentsService.fetchAnalytics();

      if (!mounted) return;
      setState(() {
        _totalBookings = bookings.length;
        _pendingBookings = bookings.where((b) => b.status == BookingStatus.pending).length;
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AuthException ? e.message : 'Could not load dashboard.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KelseyColors.adminTeal),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                style: FilledButton.styleFrom(backgroundColor: KelseyColors.adminTeal),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final analytics = _analytics;

    return RefreshIndicator(
      color: KelseyColors.adminTeal,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage platform bookings and agents.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
          ),
          const SizedBox(height: 20),
          if (analytics != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossCount = width >= 520 ? 4 : 2;
                final stats = [
                  _AdminStatData('Total Agents', '${analytics.totalAgents}', 'Registered on platform'),
                  _AdminStatData('Active Agents', '${analytics.activeAgents}', 'With recent activity'),
                  _AdminStatData(
                    'Total Paid',
                    CurrencyUtils.formatAmount(analytics.totalCommissionsPaid),
                    'Commissions disbursed',
                  ),
                  _AdminStatData(
                    'Pending',
                    CurrencyUtils.formatAmount(analytics.totalCommissionsPending),
                    'Awaiting clearance',
                  ),
                ];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: crossCount == 4 ? 1.35 : 1.15,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) => _AdminStatCard(data: stats[index]),
                );
              },
            ),
            const SizedBox(height: 16),
            _AdminSectionCard(
              title: 'Agent Analytics',
              subtitle: 'Top performing agents and commission overview',
              child: analytics.topAgents.isEmpty
                  ? _AdminEmptyState(
                      icon: Icons.groups_rounded,
                      title: 'No agent data yet',
                      subtitle: 'Agent commissions will appear here once bookings are recorded.',
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < analytics.topAgents.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _TopAgentRow(agent: analytics.topAgents[i], rank: i + 1),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
          _AdminSectionCard(
            title: 'Booking Requests',
            subtitle: 'Review and approve pending stays',
            trailing: TextButton(
              onPressed: widget.onOpenBookings,
              style: TextButton.styleFrom(foregroundColor: KelseyColors.adminTeal),
              child: const Text('View all'),
            ),
            child: InkWell(
              onTap: widget.onOpenBookings,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KelseyColors.adminTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: KelseyColors.adminTeal),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_totalBookings total · $_pendingBookings pending',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _pendingBookings > 0
                                ? '$_pendingBookings request${_pendingBookings == 1 ? '' : 's'} need review'
                                : 'All caught up — no pending requests',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _AdminSectionCard(
            title: 'Agents',
            subtitle: 'Performance indicators including at-risk status',
            trailing: TextButton(
              onPressed: widget.onOpenAgents,
              style: TextButton.styleFrom(foregroundColor: KelseyColors.adminTeal),
              child: const Text('View all'),
            ),
            child: InkWell(
              onTap: widget.onOpenAgents,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KelseyColors.adminTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.people_rounded, color: KelseyColors.adminTeal),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            analytics != null
                                ? '${analytics.totalAgents} agents · ${analytics.activeAgents} active'
                                : 'View agent list',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Active · Moderate · At Risk indicators',
                            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminStatData {
  const _AdminStatData(this.label, this.value, this.sub);
  final String label;
  final String value;
  final String sub;
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({required this.data});

  final _AdminStatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            data.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionCard extends StatelessWidget {
  const _AdminSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF9FAFB))),
              color: Color(0xFFFAFAFA),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _TopAgentRow extends StatelessWidget {
  const _TopAgentRow({required this.agent, required this.rank});

  final TopAgentItem agent;
  final int rank;

  Color get _rankBg {
    if (rank == 1) return const Color(0xFFFACC15);
    if (rank == 2) return const Color(0xFFD1D5DB);
    if (rank == 3) return const Color(0xFFFB923C);
    return const Color(0xFFE5E7EB);
  }

  Color get _rankFg {
    if (rank == 1) return KelseyColors.adminTeal;
    if (rank == 2) return const Color(0xFF374151);
    if (rank == 3) return const Color(0xFF7C2D12);
    return const Color(0xFF4B5563);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: _rankBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _rankFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.agentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${agent.totalBookings} bookings · ${agent.activeSubAgents} sub-agents · ${agent.referralCode}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyUtils.formatAmount(agent.totalCommissions),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: KelseyColors.adminTeal,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 32, color: const Color(0xFFD1D5DB)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
