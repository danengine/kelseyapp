import 'package:flutter/material.dart';

import 'kelsey_brand.dart';
import 'models/admin_agent_item.dart';
import 'services/admin_agents_service.dart';
import 'services/auth_service.dart';
import 'utils/currency_utils.dart';

/// Admin agents list with performance risk indicators.
class AdminAgentsTab extends StatefulWidget {
  const AdminAgentsTab({super.key, this.embedded = false});

  final bool embedded;

  @override
  AdminAgentsTabState createState() => AdminAgentsTabState();
}

class AdminAgentsTabState extends State<AdminAgentsTab> {
  final _service = const AdminAgentsService();

  List<AdminAgentItem> _agents = const [];
  bool _loading = true;
  String? _error;
  String _search = '';
  AgentRiskLevel? _riskFilter;

  List<AdminAgentItem> get _filtered {
    return _agents.where((agent) {
      if (_riskFilter != null && agent.riskLevel != _riskFilter) return false;
      final q = _search.trim().toLowerCase();
      if (q.isEmpty) return true;
      return agent.fullName.toLowerCase().contains(q) ||
          agent.email.toLowerCase().contains(q) ||
          agent.referralCode.toLowerCase().contains(q);
    }).toList();
  }

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
      final agents = await _service.fetchAgents();
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _agents = const [];
        _loading = false;
        _error = e is AuthException ? e.message : 'Could not load agents.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = _filtered;

    final activeCount = _agents.where((a) => a.riskLevel == AgentRiskLevel.active).length;
    final moderateCount = _agents.where((a) => a.riskLevel == AgentRiskLevel.moderate).length;
    final atRiskCount = _agents.where((a) => a.riskLevel == AgentRiskLevel.atRisk).length;

    final scrollView = RefreshIndicator(
      color: KelseyColors.adminTeal,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (!widget.embedded)
            SliverAppBar(
              pinned: true,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text('Agents'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, widget.embedded ? 12 : 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.embedded) ...[
                    Text(
                      'Agents',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    'Users with the Agent role and their booking activity.',
                    style: textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _RiskStatPill(level: AgentRiskLevel.active, count: activeCount),
                      const SizedBox(width: 8),
                      _RiskStatPill(level: AgentRiskLevel.moderate, count: moderateCount),
                      const SizedBox(width: 8),
                      _RiskStatPill(level: AgentRiskLevel.atRisk, count: atRiskCount),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search name, email, or code…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: KelseyColors.adminTeal, width: 1.5),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _RiskFilterChip(
                          label: 'All',
                          selected: _riskFilter == null,
                          onTap: () => setState(() => _riskFilter = null),
                        ),
                        ...AgentRiskLevel.values.map(
                          (level) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _RiskFilterChip(
                              label: level.label,
                              selected: _riskFilter == level,
                              color: _riskColors(level).foreground,
                              onTap: () => setState(() => _riskFilter = level),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No agents found.',
                    style: textTheme.bodyLarge?.copyWith(color: KelseyColors.cardMuted),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, widget.embedded ? 100 : 32),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _AgentCard(agent: items[index]),
                ),
              ),
          ],
        ),
    );

    if (widget.embedded) return scrollView;
    return Scaffold(body: scrollView);
  }
}

class _RiskStatPill extends StatelessWidget {
  const _RiskStatPill({required this.level, required this.count});

  final AgentRiskLevel level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = _riskColors(level);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.foreground.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: colors.dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    level.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskFilterChip extends StatelessWidget {
  const _RiskFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: (color ?? KelseyColors.adminTeal).withValues(alpha: 0.15),
      checkmarkColor: color ?? KelseyColors.adminTeal,
      labelStyle: TextStyle(
        color: selected ? (color ?? KelseyColors.adminTeal) : null,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final AdminAgentItem agent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final initials = agent.fullName.isNotEmpty
        ? agent.fullName.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: KelseyColors.adminTeal.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: const TextStyle(
                color: KelseyColors.adminTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        agent.fullName,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _RiskBadge(level: agent.riskLevel, probability: agent.riskProbability),
                  ],
                ),
                const SizedBox(height: 2),
                Text(agent.email, style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted)),
                const SizedBox(height: 8),
                Text(
                  agent.referralCode,
                  style: textTheme.labelMedium?.copyWith(
                    color: KelseyColors.adminTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _MetaChip(icon: Icons.event_note_rounded, label: agent.bookingActivityLabel),
                    if (agent.activeMonths > 0)
                      _MetaChip(
                        icon: Icons.calendar_month_outlined,
                        label: '${agent.activeMonths} active mo · ${agent.bookingsPerMonth.toStringAsFixed(1)}/mo',
                      ),
                    _MetaChip(icon: Icons.people_outline_rounded, label: '${agent.subAgentCount} sub-agents'),
                    _MetaChip(
                      icon: Icons.payments_outlined,
                      label: CurrencyUtils.formatAmount(agent.totalCommissions),
                    ),
                    _MetaChip(icon: Icons.layers_rounded, label: 'L${agent.agentLevel}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.level, this.probability});

  final AgentRiskLevel level;
  final double? probability;

  @override
  Widget build(BuildContext context) {
    final colors = _riskColors(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.foreground.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: colors.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            probability != null && probability! > 0
                ? '${level.label} · ${probability!.toStringAsFixed(0)}%'
                : level.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: KelseyColors.cardMuted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: KelseyColors.cardMuted)),
      ],
    );
  }
}

({Color background, Color foreground, Color dot}) _riskColors(AgentRiskLevel level) {
  switch (level) {
    case AgentRiskLevel.active:
      return (
        background: const Color(0xFFD1FAE5),
        foreground: const Color(0xFF065F46),
        dot: const Color(0xFF10B981),
      );
    case AgentRiskLevel.moderate:
      return (
        background: const Color(0xFFFFEDD5),
        foreground: const Color(0xFF9A3412),
        dot: const Color(0xFFF97316),
      );
    case AgentRiskLevel.atRisk:
      return (
        background: const Color(0xFFFEE2E2),
        foreground: const Color(0xFF991B1B),
        dot: const Color(0xFFEF4444),
      );
  }
}
