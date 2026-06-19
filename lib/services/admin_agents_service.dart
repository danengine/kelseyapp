import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/admin_agent_item.dart';
import 'auth_service.dart';
import 'auth_session.dart';

class AdminAgentsService {
  const AdminAgentsService();

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

  Future<List<AdminAgentItem>> fetchAgents({int limit = 100}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/users').replace(
      queryParameters: {'role': 'Agent', 'limit': '$limit', 'page': '1'},
    );

    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      body = null;
    }

    if (response.statusCode == 403) {
      throw AuthException('Admin access required.');
    }
    if (response.statusCode != 200 || body == null) {
      throw AuthException(
        body?['error'] as String? ?? 'Failed to load agents (${response.statusCode}).',
      );
    }

    final users = body['users'];
    if (users is! List) return const [];

    return users
        .whereType<Map<String, dynamic>>()
        .map(AdminAgentItem.fromJson)
        .where((a) => a.id.isNotEmpty)
        .toList();
  }

  Future<AdminAnalyticsSummary> fetchAnalytics() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/admin/analytics');

    http.Response response;
    try {
      response = await http.get(uri, headers: _authHeaders()).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException(
        'Could not reach the server at ${ApiConfig.baseUrl}. ${ApiConfig.connectivityHint}',
      );
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      body = null;
    }

    if (response.statusCode == 403) {
      throw AuthException('Admin access required.');
    }
    if (response.statusCode != 200 || body == null) {
      throw AuthException(
        body?['error'] as String? ?? 'Failed to load analytics (${response.statusCode}).',
      );
    }

    return AdminAnalyticsSummary.fromJson(body);
  }
}
