/// Admin agent row from GET /api/users?role=Agent.
enum AgentRiskLevel {
  active,
  moderate,
  atRisk;

  String get label {
    switch (this) {
      case AgentRiskLevel.active:
        return 'Active';
      case AgentRiskLevel.moderate:
        return 'Moderate';
      case AgentRiskLevel.atRisk:
        return 'At Risk';
    }
  }

  /// Green / orange / red performance indicator (from ML risk prediction API).
  static AgentRiskLevel fromApi({
    required String? riskLevel,
    required String? riskStatus,
    required String? riskCategory,
  }) {
    switch ((riskLevel ?? '').toLowerCase()) {
      case 'atrisk':
      case 'at_risk':
        return AgentRiskLevel.atRisk;
      case 'moderate':
        return AgentRiskLevel.moderate;
      case 'active':
        return AgentRiskLevel.active;
      default:
        break;
    }
    if (riskStatus == 'Active' && riskCategory == 'Low') return AgentRiskLevel.active;
    if (riskCategory == 'High') return AgentRiskLevel.atRisk;
    if (riskCategory == 'Moderate' || riskStatus == 'At Risk') return AgentRiskLevel.moderate;
    return AgentRiskLevel.active;
  }
}

class AdminAgentItem {
  const AdminAgentItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.status,
    required this.bookingCount,
    required this.subAgentCount,
    required this.agentLevel,
    required this.totalCommissions,
    required this.riskLevel,
    required this.riskStatus,
    required this.riskProbability,
    required this.riskCategory,
    this.recentBookingCount = 0,
    this.bookingsPerMonth = 0,
    this.daysSinceLastBooking,
    this.activeMonths = 0,
  });

  final String id;
  final String fullName;
  final String email;
  final String status;
  final int bookingCount;
  final int subAgentCount;
  final int agentLevel;
  final double totalCommissions;
  final AgentRiskLevel riskLevel;
  final String riskStatus;
  final double riskProbability;
  final String riskCategory;
  final int recentBookingCount;
  final double bookingsPerMonth;
  final int? daysSinceLastBooking;
  final int activeMonths;

  String get referralCode => 'AGENT-$id';

  String get bookingActivityLabel {
    final recent = recentBookingCount > 0 ? recentBookingCount : bookingCount;
    final last = daysSinceLastBooking;
    if (last == null) return '$recent bookings';
    if (last >= 999) return recent > 0 ? '$recent bookings · no recent activity' : 'No bookings';
    if (last == 0) return '$recent bookings · today';
    if (last == 1) return '$recent bookings · last 1d ago';
    return '$recent bookings · last ${last}d ago';
  }

  factory AdminAgentItem.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as String? ?? 'inactive';
    final bookingCount = (json['bookingCount'] as num?)?.toInt() ?? 0;
    final riskStatus = json['riskStatus'] as String? ?? 'Active';
    final riskCategory = json['riskCategory'] as String? ?? 'Low';
    final riskProbability = (json['riskProbability'] as num?)?.toDouble() ?? 0;
    return AdminAgentItem(
      id: '${json['id']}',
      fullName: json['fullname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: status,
      bookingCount: bookingCount,
      subAgentCount: (json['subAgentCount'] as num?)?.toInt() ?? 0,
      agentLevel: (json['agentLevel'] as num?)?.toInt() ?? 1,
      totalCommissions: (json['totalCommissions'] as num?)?.toDouble() ?? 0,
      riskLevel: AgentRiskLevel.fromApi(
        riskLevel: json['riskLevel'] as String?,
        riskStatus: riskStatus,
        riskCategory: riskCategory,
      ),
      riskStatus: riskStatus,
      riskProbability: riskProbability,
      riskCategory: riskCategory,
      recentBookingCount: (json['recentBookingCount'] as num?)?.toInt() ?? 0,
      bookingsPerMonth: (json['bookingsPerMonth'] as num?)?.toDouble() ?? 0,
      daysSinceLastBooking: (json['daysSinceLastBooking'] as num?)?.toInt(),
      activeMonths: (json['activeMonths'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopAgentItem {
  const TopAgentItem({
    required this.agentId,
    required this.agentName,
    required this.referralCode,
    required this.totalCommissions,
    required this.totalBookings,
    required this.activeSubAgents,
  });

  final String agentId;
  final String agentName;
  final String referralCode;
  final double totalCommissions;
  final int totalBookings;
  final int activeSubAgents;

  factory TopAgentItem.fromJson(Map<String, dynamic> json) {
    return TopAgentItem(
      agentId: '${json['agentId'] ?? json['agent_id'] ?? ''}',
      agentName: json['agentName'] as String? ?? json['agent_name'] as String? ?? 'Agent',
      referralCode: json['referralCode'] as String? ?? json['referral_code'] as String? ?? '',
      totalCommissions: (json['totalCommissions'] as num?)?.toDouble() ??
          (json['total_commissions'] as num?)?.toDouble() ??
          0,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ??
          (json['total_bookings'] as num?)?.toInt() ??
          0,
      activeSubAgents: (json['activeSubAgents'] as num?)?.toInt() ??
          (json['active_sub_agents'] as num?)?.toInt() ??
          0,
    );
  }
}

class AdminAnalyticsSummary {
  const AdminAnalyticsSummary({
    required this.totalAgents,
    required this.activeAgents,
    required this.totalCommissionsPaid,
    required this.totalCommissionsPending,
    required this.topAgents,
  });

  final int totalAgents;
  final int activeAgents;
  final double totalCommissionsPaid;
  final double totalCommissionsPending;
  final List<TopAgentItem> topAgents;

  factory AdminAnalyticsSummary.fromJson(Map<String, dynamic> json) {
    final topRaw = json['topAgents'] ?? json['top_agents'];
    final topAgents = topRaw is List
        ? topRaw
            .whereType<Map<String, dynamic>>()
            .map(TopAgentItem.fromJson)
            .where((a) => a.agentId.isNotEmpty)
            .toList()
        : const <TopAgentItem>[];

    return AdminAnalyticsSummary(
      totalAgents: (json['totalAgents'] as num?)?.toInt() ?? 0,
      activeAgents: (json['activeAgents'] as num?)?.toInt() ?? 0,
      totalCommissionsPaid: (json['totalCommissionsPaid'] as num?)?.toDouble() ?? 0,
      totalCommissionsPending: (json['totalCommissionsPending'] as num?)?.toDouble() ?? 0,
      topAgents: topAgents,
    );
  }
}
