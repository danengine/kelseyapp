import 'package:flutter/material.dart';

import 'kelsey_brand.dart';
import 'models/rewards_models.dart';
import 'services/rewards_service.dart';

const _rewardsTeal = Color(0xFF0B5858);
const _rewardsTealDark = Color(0xFF094848);
const _rewardsAmber = Color(0xFFFACC15);

/// Rewards Hub — balance, activity, and redemption (mirrors web `/rewards`).
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> with SingleTickerProviderStateMixin {
  final _service = const RewardsService();
  late final TabController _tabController;

  AgentPointsBalance? _balance;
  List<PointsTransaction> _history = [];
  bool _loading = true;
  String? _error;
  _StatsPeriod _statsPeriod = _StatsPeriod.month;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getRewardsData();
      if (!mounted) return;
      setState(() {
        _balance = data.balance;
        _history = data.transactions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _appendLocalRedemption(PointsTransaction tx) {
    setState(() {
      _history = [tx, ..._history].take(pointsHistoryMaxLimit).toList();
      if (_balance != null) {
        _balance = AgentPointsBalance(
          agentId: _balance!.agentId,
          totalPoints: _balance!.totalPoints + tx.points,
          updatedAt: DateTime.now(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _loading || _error != null
          ? AppBar(
              title: const Text('Rewards Hub'),
              backgroundColor: _rewardsTeal,
              foregroundColor: Colors.white,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _rewardsTeal))
          : _error != null
              ? _RewardsMaintenance(onRetry: _load)
              : Column(
                  children: [
                    _RewardsTopSection(
                      tabController: _tabController,
                      balance: _balance?.totalPoints ?? 0,
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _OverviewTab(
                            history: _history,
                            statsPeriod: _statsPeriod,
                            onStatsPeriodChanged: (p) => setState(() => _statsPeriod = p),
                            onViewAll: () => _showActivitySheet(context),
                          ),
                          _RedeemTab(
                            balance: _balance?.totalPoints ?? 0,
                            onRedeem: (reward) => _showRedeemDialog(reward),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _showActivitySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ActivityHistorySheet(history: _history),
    );
  }

  Future<void> _showRedeemDialog(RewardOption reward) async {
    final result = await showDialog<PointsTransaction>(
      context: context,
      builder: (ctx) => _RedeemConfirmDialog(
        reward: reward,
        currentBalance: _balance?.totalPoints ?? 0,
      ),
    );
    if (result == null || !mounted) return;
    _appendLocalRedemption(result);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Redemption Submitted!'),
        content: Text(
          'Your request for ${reward.name} is pending admin approval.\n\n'
          "You'll be notified once it's approved and issued.",
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _rewardsTeal),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

enum _StatsPeriod { week, month, all }

class _RewardsTopSection extends StatelessWidget {
  const _RewardsTopSection({
    required this.tabController,
    required this.balance,
  });

  final TabController tabController;
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D6B6B), _rewardsTeal, _rewardsTealDark],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Rewards Hub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Book. Earn. Redeem. Track points from confirmed bookings.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _PointsBalanceCard(balance: balance),
                  ),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: Colors.black12,
          child: TabBar(
            controller: tabController,
            indicatorColor: _rewardsTeal,
            indicatorWeight: 3,
            labelColor: _rewardsTeal,
            unselectedLabelColor: KelseyColors.cardMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Redeem'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PointsBalanceCard extends StatelessWidget {
  const _PointsBalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF083F3F),
        border: Border.all(color: const Color(0xFF18A2A2).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Points balance',
                  style: TextStyle(
                    color: Colors.amber.shade100,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _formatNumber(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: ' pts',
                        style: TextStyle(
                          color: Colors.amber.shade100,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _rewardsAmber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Available',
              style: TextStyle(
                color: _rewardsTeal,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.history,
    required this.statsPeriod,
    required this.onStatsPeriodChanged,
    required this.onViewAll,
  });

  final List<PointsTransaction> history;
  final _StatsPeriod statsPeriod;
  final ValueChanged<_StatsPeriod> onStatsPeriodChanged;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final filtered = _filterByPeriod(history, statsPeriod);
    final earned = filtered.where((tx) => tx.points > 0).fold<int>(0, (s, tx) => s + tx.points);
    final redeemed = filtered.where((tx) => tx.points < 0).fold<int>(0, (s, tx) => s + tx.points.abs());
    final bookings = filtered.where((tx) => tx.type == PointsTransactionType.booking).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _StatsCard(
          earned: earned,
          redeemed: redeemed,
          bookings: bookings,
          period: statsPeriod,
          onPeriodChanged: onStatsPeriodChanged,
        ),
        const SizedBox(height: 16),
        _ActivityCard(
          history: history,
          onViewAll: history.isEmpty ? null : onViewAll,
        ),
        const SizedBox(height: 24),
        const _TermsSection(),
      ],
    );
  }

  static List<PointsTransaction> _filterByPeriod(List<PointsTransaction> history, _StatsPeriod period) {
    final now = DateTime.now();
    if (period == _StatsPeriod.all) return history;
    if (period == _StatsPeriod.week) {
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday % 7));
      return history.where((tx) => tx.createdAt.isAfter(start)).toList();
    }
    final start = DateTime(now.year, now.month, 1);
    return history.where((tx) => tx.createdAt.isAfter(start)).toList();
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.earned,
    required this.redeemed,
    required this.bookings,
    required this.period,
    required this.onPeriodChanged,
  });

  final int earned;
  final int redeemed;
  final int bookings;
  final _StatsPeriod period;
  final ValueChanged<_StatsPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                DropdownButton<_StatsPeriod>(
                  value: period,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(value: _StatsPeriod.week, child: Text('This Week')),
                    DropdownMenuItem(value: _StatsPeriod.month, child: Text('This Month')),
                    DropdownMenuItem(value: _StatsPeriod.all, child: Text('All Time')),
                  ],
                  onChanged: (v) {
                    if (v != null) onPeriodChanged(v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTile(label: 'Earned', value: '${_formatNumber(earned)} pts')),
                const SizedBox(width: 8),
                Expanded(child: _StatTile(label: 'Redeemed', value: '${_formatNumber(redeemed)} pts')),
                const SizedBox(width: 8),
                Expanded(child: _StatTile(label: 'Bookings', value: '$bookings')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _rewardsTeal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.history, this.onViewAll});

  final List<PointsTransaction> history;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (onViewAll != null)
                  TextButton(onPressed: onViewAll, child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No activity yet.', style: TextStyle(color: Colors.grey.shade500))),
              )
            else
              ...history.take(5).map((tx) => _TransactionTile(tx: tx)),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final PointsTransaction tx;

  @override
  Widget build(BuildContext context) {
    final isRejected = tx.type == PointsTransactionType.redemption && tx.status == RedemptionStatus.rejected;
    final displayPoints = isRejected ? tx.points.abs() : tx.points;
    final showAsRefund = isRejected;
    final title = tx.type == PointsTransactionType.redemption
        ? 'Redeemed for ${tx.description.replaceFirst(RegExp(r'^Redeemed for\s*', caseSensitive: false), '')}'
        : tx.description;
    final statusLabel = _redemptionStatusLabel(tx);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${_formatDateTime(tx.createdAt)}${statusLabel != null ? ' · $statusLabel' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            '${showAsRefund || displayPoints >= 0 ? '+' : '-'}${_formatNumber(displayPoints.abs())} pts',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: showAsRefund || displayPoints >= 0 ? _rewardsTeal : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityHistorySheet extends StatefulWidget {
  const _ActivityHistorySheet({required this.history});

  final List<PointsTransaction> history;

  @override
  State<_ActivityHistorySheet> createState() => _ActivityHistorySheetState();
}

class _ActivityHistorySheetState extends State<_ActivityHistorySheet> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(widget.history, _filter);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Text('Activity History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(label: 'All', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                  _FilterChip(label: 'Earned', selected: _filter == 'earned', onTap: () => setState(() => _filter = 'earned')),
                  _FilterChip(label: 'Redeemed', selected: _filter == 'redeemed', onTap: () => setState(() => _filter = 'redeemed')),
                  _FilterChip(label: 'Pending', selected: _filter == 'pending', onTap: () => setState(() => _filter = 'pending')),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('No activity yet.', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _TransactionTile(tx: filtered[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  static List<PointsTransaction> _applyFilter(List<PointsTransaction> history, String filter) {
    switch (filter) {
      case 'earned':
        return history.where((tx) => tx.points > 0).toList();
      case 'redeemed':
        return history
            .where((tx) =>
                tx.type == PointsTransactionType.redemption &&
                tx.points < 0 &&
                tx.status != RedemptionStatus.pending)
            .toList();
      case 'pending':
        return history
            .where((tx) =>
                tx.type == PointsTransactionType.redemption && tx.status == RedemptionStatus.pending)
            .toList();
      default:
        return history;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _rewardsTeal.withValues(alpha: 0.15),
        checkmarkColor: _rewardsTeal,
        labelStyle: TextStyle(
          color: selected ? _rewardsTeal : Colors.black87,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _RedeemTab extends StatelessWidget {
  const _RedeemTab({required this.balance, required this.onRedeem});

  final int balance;
  final ValueChanged<RewardOption> onRedeem;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: rewardCatalog.length,
      itemBuilder: (context, index) {
        final reward = rewardCatalog[index];
        final canRedeem = balance >= reward.pointsCost;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  child: Icon(reward.icon ?? Icons.card_giftcard_rounded, size: 48, color: _rewardsTeal.withValues(alpha: 0.5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Text(reward.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Row(
                  children: [
                    Text(
                      '${_formatNumber(reward.pointsCost)} pts',
                      style: const TextStyle(color: _rewardsTeal, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (reward.stock != null) ...[
                      const Spacer(),
                      Text('${reward.stock} left', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _rewardsTeal,
                    disabledBackgroundColor: _rewardsTeal.withValues(alpha: 0.4),
                  ),
                  onPressed: canRedeem ? () => onRedeem(reward) : null,
                  child: Text(canRedeem ? 'Redeem' : 'Insufficient'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RedeemConfirmDialog extends StatefulWidget {
  const _RedeemConfirmDialog({required this.reward, required this.currentBalance});

  final RewardOption reward;
  final int currentBalance;

  @override
  State<_RedeemConfirmDialog> createState() => _RedeemConfirmDialogState();
}

class _RedeemConfirmDialogState extends State<_RedeemConfirmDialog> {
  int _quantity = 1;
  CashPaymentMethod? _paymentMethod;
  final _recipientNumber = TextEditingController();
  final _recipientName = TextEditingController();
  DateTime? _preferredDate;

  bool get _isCash => widget.reward.id.startsWith('cash-');
  bool get _isStaycation => widget.reward.id == 'tshirt';

  int get _totalPoints => widget.reward.pointsCost * _quantity;
  int get _balanceAfter => widget.currentBalance - _totalPoints;

  bool get _canConfirm {
    if (_isCash) {
      return _paymentMethod != null &&
          _recipientNumber.text.trim().isNotEmpty &&
          _recipientName.text.trim().isNotEmpty;
    }
    if (_isStaycation) return _preferredDate != null;
    return true;
  }

  @override
  void dispose() {
    _recipientNumber.dispose();
    _recipientName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirm Redemption'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Icon(widget.reward.icon ?? Icons.card_giftcard_rounded, size: 56, color: _rewardsTeal),
            ),
            const SizedBox(height: 8),
            Text(widget.reward.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_isCash) ...[
              const Text('Payment details', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<CashPaymentMethod>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: CashPaymentMethod.gcash, child: Text('GCash')),
                  DropdownMenuItem(value: CashPaymentMethod.paymaya, child: Text('Maya')),
                  DropdownMenuItem(value: CashPaymentMethod.bankTransfer, child: Text('Bank transfer')),
                ],
                onChanged: (v) => setState(() => _paymentMethod = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _recipientNumber,
                decoration: InputDecoration(
                  labelText: _paymentMethod == CashPaymentMethod.bankTransfer ? 'Account no.' : 'Mobile no.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _recipientName,
                decoration: const InputDecoration(labelText: 'Recipient name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
            ],
            if (_isStaycation) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Preferred date'),
                subtitle: Text(_preferredDate == null ? 'Tap to select' : _formatDate(_preferredDate!)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _preferredDate = picked);
                },
              ),
              const SizedBox(height: 8),
            ],
            _PointsRow(label: 'Points per item', value: '${_formatNumber(widget.reward.pointsCost)} pts'),
            _PointsRow(label: 'Total points required', value: '${_formatNumber(_totalPoints)} pts'),
            _PointsRow(label: 'Your Balance', value: '${_formatNumber(widget.currentBalance)} pts'),
            const Divider(),
            _PointsRow(label: 'Balance After', value: '${_formatNumber(_balanceAfter)} pts', highlight: true),
            const SizedBox(height: 8),
            Text('⚠ This action cannot be undone.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _rewardsTeal),
          onPressed: _canConfirm
              ? () {
                  final tx = PointsTransaction(
                    id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
                    agentId: '',
                    points: -_totalPoints,
                    type: PointsTransactionType.redemption,
                    description: widget.reward.name,
                    createdAt: DateTime.now(),
                    status: RedemptionStatus.pending,
                    paymentMethod: _isCash ? _paymentMethod : null,
                    recipientNumber: _isCash ? _recipientNumber.text.trim() : null,
                    recipientName: _isCash ? _recipientName.text.trim() : null,
                    preferredDates: _isStaycation && _preferredDate != null ? _formatDate(_preferredDate!) : null,
                  );
                  Navigator.pop(context, tx);
                }
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _PointsRow extends StatelessWidget {
  const _PointsRow({required this.label, required this.value, this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? _rewardsTeal : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rewards Hub Terms & Conditions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._termsSections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...section.bullets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: KelseyColors.cardMuted)),
                        Expanded(child: Text(b, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TermSection {
  const _TermSection(this.title, this.bullets);
  final String title;
  final List<String> bullets;
}

const _termsSections = [
  _TermSection('1. Eligibility & Registration', [
    'Only registered and active agents of Kelsey\'s Homestay are eligible to earn and redeem points.',
    'Agents must maintain a verified account within the system to participate in the Rewards Hub.',
    'Sub-accounts or duplicate registrations are strictly prohibited.',
  ]),
  _TermSection('2. Earning Points', [
    'Points are awarded exclusively for confirmed bookings.',
    '50 points per confirmed booking (Base) + 25 points per night of stay (Bonus).',
    'Example: A 3-night booking earns 50 + (25 × 3) = 125 points.',
    'Points are credited once a booking is marked as Confirmed (allow up to 24 hours).',
  ]),
  _TermSection('3. Point Validity', [
    'Points do not expire as long as the agent\'s account remains active.',
    'If an account is deactivated, unredeemed points are forfeited.',
  ]),
  _TermSection('4. Redeeming Rewards', [
    'All redemption requests are subject to admin approval.',
    'Cash rewards: GCash, bank transfer, or other official methods. Processing 3–7 business days.',
    'Free night stays: subject to availability, 7-day advance booking required.',
    'Merchandise and goods are subject to stock availability.',
  ]),
  _TermSection('5. Contact & Disputes', [
    'For questions regarding point totals, contact admin via platform support.',
    'Dispute claims reviewed within 7 business days.',
    'Kelsey\'s Homestay administration decisions are final.',
  ]),
];

class _RewardsMaintenance extends StatelessWidget {
  const _RewardsMaintenance({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _rewardsTeal.withValues(alpha: 0.2), width: 2),
                ),
                child: const Icon(Icons.settings_rounded, size: 36, color: _rewardsTeal),
              ),
              const SizedBox(height: 24),
              const Text('Under Maintenance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                "We're making some improvements to the Rewards system. Please check back in a little while.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _rewardsTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _redemptionStatusLabel(PointsTransaction tx) {
  if (tx.type != PointsTransactionType.redemption || tx.status == null) return null;
  switch (tx.status!) {
    case RedemptionStatus.pending:
      return 'Pending approval';
    case RedemptionStatus.approved:
      return 'Approved';
    case RedemptionStatus.issued:
      return 'Issued';
    case RedemptionStatus.rejected:
      return 'Rejected — points refunded';
  }
}

String _formatNumber(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final pos = s.length - i;
    buf.write(s[i]);
    if (pos > 1 && pos % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

String _formatDateTime(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${_month(dt.month)} ${dt.day}, ${dt.year} $h:$min $ampm';
}

String _formatDate(DateTime dt) => '${_month(dt.month)} ${dt.day}, ${dt.year}';

String _month(int m) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return months[m - 1];
}
