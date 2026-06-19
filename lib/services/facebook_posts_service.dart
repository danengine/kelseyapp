import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/facebook_post.dart';
import 'auth_service.dart';

class FacebookPostsService {
  const FacebookPostsService();

  Future<List<FacebookPost>> fetchPosts() async {
    final uri = Uri.parse(ApiConfig.facebookPostsUrl);
    http.Response response;

    try {
      response = await http.get(uri).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw AuthException(
        'Could not reach the scraper at ${ApiConfig.scraperBaseUrl}. '
        'Ensure datascraping is running on port ${ApiConfig.scraperPort}.',
      );
    }

    if (response.statusCode != 200) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        body = null;
      }
      throw AuthException(
        body?['error'] as String? ?? 'Failed to load Facebook posts (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];

    final rawPosts = decoded['posts'];
    if (rawPosts is! List) return const [];

    return _dedupeAndSort(
      rawPosts
          .whereType<Map<String, dynamic>>()
          .map(FacebookPost.fromJson)
          .where((post) => post.content.isNotEmpty),
    );
  }

  Future<void> deletePost(String id) => deletePosts([id]);

  Future<void> deletePosts(List<String> ids) async {
    final cleaned = ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
    if (cleaned.isEmpty) return;

    try {
      await _deletePostsRequest(cleaned);
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      final bulkFallback =
          cleaned.length > 1 && (message.contains('id is required') || message.contains('ids is required'));
      if (!bulkFallback) rethrow;

      for (final id in cleaned) {
        await _deletePostsRequest([id]);
      }
    }
  }

  Future<void> _deletePostsRequest(List<String> ids) async {
    final uri = Uri.parse(ApiConfig.facebookPostsDeleteUrl);
    final payload = <String, dynamic>{
      'ids': ids,
      if (ids.length == 1) 'id': ids.first,
    };

    http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw AuthException(
        'Could not reach the scraper at ${ApiConfig.scraperBaseUrl}.',
      );
    }

    if (response.statusCode != 200) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        body = null;
      }
      throw AuthException(
        body?['error'] as String? ?? 'Failed to delete posts (${response.statusCode}).',
      );
    }
  }

  List<FacebookPost> _dedupeAndSort(Iterable<FacebookPost> posts) {
    final byId = <String, FacebookPost>{};
    final seenContent = <String>{};

    for (final post in posts) {
      final contentKey = '${post.profileName}|${post.content}'.trim().toLowerCase();
      if (byId.containsKey(post.id) || seenContent.contains(contentKey)) continue;
      byId[post.id] = post;
      seenContent.add(contentKey);
    }

    final sorted = byId.values.toList()
      ..sort((a, b) {
        final aTime = a.postedAt;
        final bTime = b.postedAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
    return sorted;
  }
}
