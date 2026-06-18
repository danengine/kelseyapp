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
    final uri = Uri.parse(ApiConfig.rewardsMeUrl);
    http.Response response;

    try {
      response = await http
          .get(uri, headers: _authHeaders())
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw RewardsException(maintenanceMessage);
    }

    if (response.statusCode == 401) {
      throw RewardsException('Please log in again to view rewards.');
    }
    if (response.statusCode == 403) {
      throw RewardsException('Access denied. Agent or Admin role required.');
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

    return RewardsData(
      balance: balance,
      transactions: transactions.take(pointsHistoryMaxLimit).toList(),
    );
  }
}
