import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/rewards_models.dart';
import 'auth_service.dart';
import 'auth_session.dart';

class RewardsException implements Exception {
  RewardsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RewardsService {
  const RewardsService();

  static const maintenanceMessage = 'Rewards is currently under maintenance.';

  Map<String, String> _authHeaders() {
    final token = AuthSession.accessToken;
    if (token == null || token.isEmpty) {
      throw AuthException('Please log in to continue.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<RewardsData> getRewardsData() async {
    final headers = _authHeaders();
    final meFuture = _fetchRewardsMe(headers);
    final leaderboardFuture = _fetchLeaderboard(headers);

    final me = await meFuture;
    final leaderboardPayload = await leaderboardFuture;

    if (me != null) {
      return RewardsData(
        balance: me.balance,
        transactions: me.transactions,
        leaderboard: me.leaderboard.isNotEmpty ? me.leaderboard : leaderboardPayload.leaderboard,
        myRank: me.myRank ?? leaderboardPayload.myRank,
        isAgentView: true,
      );
    }

    return RewardsData(
      leaderboard: leaderboardPayload.leaderboard,
      myRank: leaderboardPayload.myRank,
      isAgentView: false,
    );
  }

  Future<_RewardsMePayload?> _fetchRewardsMe(Map<String, String> headers) async {
    final uri = Uri.parse(ApiConfig.rewardsMeUrl);
    http.Response response;

    try {
      response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw RewardsException(maintenanceMessage);
    }

    if (response.statusCode == 401) {
      throw RewardsException('Please log in again to view rewards.');
    }
    if (response.statusCode == 403) {
      return null;
    }
    if (response.statusCode != 200) {
      throw RewardsException(maintenanceMessage);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final balance = AgentPointsBalance.fromJson(body);
    final rawActivity = body['recentActivity'];
    final transactions = <PointsTransaction>[];
    if (rawActivity is List) {
      for (final item in rawActivity) {
        if (item is Map<String, dynamic>) {
          transactions.add(PointsTransaction.fromJson(item));
        }
      }
    }

    final leaderboard = _parseLeaderboard(body['leaderboard']);
    final myRankRaw = body['myRank'];

    return _RewardsMePayload(
      balance: balance,
      transactions: transactions.take(pointsHistoryMaxLimit).toList(),
      leaderboard: leaderboard,
      myRank: myRankRaw is Map<String, dynamic> ? LeaderboardRank.fromJson(myRankRaw) : null,
    );
  }

  List<LeaderboardEntry> _parseLeaderboard(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(LeaderboardEntry.fromJson).toList();
  }

  Future<_LeaderboardPayload> _fetchLeaderboard(Map<String, String> headers) async {
    final uri = Uri.parse('${ApiConfig.rewardsLeaderboardUrl}?limit=50');
    try {
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw RewardsException('Please log in again to view rewards.');
      }
      if (response.statusCode != 200) {
        return const _LeaderboardPayload();
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = body['leaderboard'];
      final entries = raw is List
          ? raw.whereType<Map<String, dynamic>>().map(LeaderboardEntry.fromJson).toList()
          : <LeaderboardEntry>[];
      final myRankRaw = body['myRank'];
      return _LeaderboardPayload(
        leaderboard: entries,
        myRank: myRankRaw is Map<String, dynamic> ? LeaderboardRank.fromJson(myRankRaw) : null,
      );
    } on RewardsException {
      rethrow;
    } catch (_) {
      return const _LeaderboardPayload();
    }
  }
}

class _RewardsMePayload {
  const _RewardsMePayload({
    required this.balance,
    required this.transactions,
    this.leaderboard = const [],
    this.myRank,
  });

  final AgentPointsBalance balance;
  final List<PointsTransaction> transactions;
  final List<LeaderboardEntry> leaderboard;
  final LeaderboardRank? myRank;
}

class _LeaderboardPayload {
  const _LeaderboardPayload({this.leaderboard = const [], this.myRank});

  final List<LeaderboardEntry> leaderboard;
  final LeaderboardRank? myRank;
}
