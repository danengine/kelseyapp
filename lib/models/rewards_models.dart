import 'package:flutter/material.dart' show IconData, Icons;

/// Reward and point system types for agents (mirrors kelseybackend/frontend types).

class AgentPointsBalance {
  const AgentPointsBalance({
    required this.agentId,
    required this.totalPoints,
    required this.updatedAt,
  });

  final String agentId;
  final int totalPoints;
  final DateTime updatedAt;

  factory AgentPointsBalance.fromJson(Map<String, dynamic> json) {
    final updated = json['updatedAt'];
    return AgentPointsBalance(
      agentId: json['agentId']?.toString() ?? '',
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      updatedAt: updated is String
          ? DateTime.parse(updated)
          : DateTime.now(),
    );
  }
}

enum PointsTransactionType { booking, bonus, redemption, adjustment }

enum RedemptionStatus { pending, approved, issued, rejected }

enum CashPaymentMethod { gcash, paymaya, bankTransfer }

class PointsTransaction {
  const PointsTransaction({
    required this.id,
    required this.agentId,
    required this.points,
    required this.type,
    required this.description,
    required this.createdAt,
    this.referenceId,
    this.status,
    this.paymentMethod,
    this.recipientNumber,
    this.recipientName,
    this.preferredDates,
  });

  final String id;
  final String agentId;
  final int points;
  final PointsTransactionType type;
  final String description;
  final DateTime createdAt;
  final String? referenceId;
  final RedemptionStatus? status;
  final CashPaymentMethod? paymentMethod;
  final String? recipientNumber;
  final String? recipientName;
  final String? preferredDates;

  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    return PointsTransaction(
      id: json['id']?.toString() ?? '',
      agentId: json['agentId']?.toString() ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      type: _parseType(json['type'] as String?),
      description: json['description'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      referenceId: json['referenceId']?.toString(),
      status: _parseStatus(json['status'] as String?),
      paymentMethod: _parsePaymentMethod(json['paymentMethod'] as String?),
      recipientNumber: json['recipientNumber'] as String?,
      recipientName: json['recipientName'] as String?,
      preferredDates: json['preferredDates'] as String?,
    );
  }

  PointsTransaction copyWith({
    String? id,
    String? agentId,
    int? points,
    PointsTransactionType? type,
    String? description,
    DateTime? createdAt,
    String? referenceId,
    RedemptionStatus? status,
    CashPaymentMethod? paymentMethod,
    String? recipientNumber,
    String? recipientName,
    String? preferredDates,
  }) {
    return PointsTransaction(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      points: points ?? this.points,
      type: type ?? this.type,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      referenceId: referenceId ?? this.referenceId,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      recipientNumber: recipientNumber ?? this.recipientNumber,
      recipientName: recipientName ?? this.recipientName,
      preferredDates: preferredDates ?? this.preferredDates,
    );
  }

  static PointsTransactionType _parseType(String? raw) {
    switch (raw) {
      case 'bonus':
        return PointsTransactionType.bonus;
      case 'redemption':
        return PointsTransactionType.redemption;
      case 'adjustment':
        return PointsTransactionType.adjustment;
      default:
        return PointsTransactionType.booking;
    }
  }

  static RedemptionStatus? _parseStatus(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw == 'requested') return RedemptionStatus.pending;
    switch (raw) {
      case 'pending':
        return RedemptionStatus.pending;
      case 'approved':
        return RedemptionStatus.approved;
      case 'issued':
        return RedemptionStatus.issued;
      case 'rejected':
        return RedemptionStatus.rejected;
      default:
        return null;
    }
  }

  static CashPaymentMethod? _parsePaymentMethod(String? raw) {
    switch (raw) {
      case 'gcash':
        return CashPaymentMethod.gcash;
      case 'paymaya':
        return CashPaymentMethod.paymaya;
      case 'bank_transfer':
        return CashPaymentMethod.bankTransfer;
      default:
        return null;
    }
  }
}

class RewardsData {
  const RewardsData({
    this.balance,
    this.transactions = const [],
    this.leaderboard = const [],
    this.myRank,
    this.isAgentView = false,
  });

  final AgentPointsBalance? balance;
  final List<PointsTransaction> transactions;
  final List<LeaderboardEntry> leaderboard;
  final LeaderboardRank? myRank;
  final bool isAgentView;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.agentId,
    required this.agentName,
    required this.totalPoints,
    required this.totalBookings,
    required this.isCurrentUser,
  });

  final int rank;
  final String agentId;
  final String agentName;
  final int totalPoints;
  final int totalBookings;
  final bool isCurrentUser;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      agentId: json['agentId']?.toString() ?? '',
      agentName: json['agentName'] as String? ?? 'Agent',
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
      isCurrentUser: json['isCurrentUser'] == true,
    );
  }
}

class LeaderboardRank {
  const LeaderboardRank({
    required this.rank,
    required this.totalPoints,
    required this.totalBookings,
  });

  final int rank;
  final int totalPoints;
  final int totalBookings;

  factory LeaderboardRank.fromJson(Map<String, dynamic> json) {
    return LeaderboardRank(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
      totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Catalog item for the Redeem tab (mock until catalog API exists).
class RewardOption {
  const RewardOption({
    required this.id,
    required this.name,
    required this.pointsCost,
    this.stock,
    this.icon,
  });

  final String id;
  final String name;
  final int pointsCost;
  final int? stock;
  final IconData? icon;
}

const int pointsHistoryMaxLimit = 20;

const List<RewardOption> rewardCatalog = [
  RewardOption(id: 'cash-500', name: '₱500 Cash', pointsCost: 1000, icon: Icons.payments_rounded),
  RewardOption(id: 'cash-1000', name: '₱1,000 Cash', pointsCost: 2000, icon: Icons.payments_rounded),
  RewardOption(id: 'tumbler', name: 'Tumbler', pointsCost: 2000, stock: 12, icon: Icons.local_cafe_rounded),
  RewardOption(id: 'rice', name: '1 sack of rice', pointsCost: 1000, stock: 5, icon: Icons.rice_bowl_rounded),
  RewardOption(
    id: 'tshirt',
    name: 'Free 1 Night Staycation',
    pointsCost: 5000,
    stock: 8,
    icon: Icons.night_shelter_rounded,
  ),
];
