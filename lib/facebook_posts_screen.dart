import 'dart:async';

import 'package:flutter/material.dart';

import 'kelsey_brand.dart';
import 'models/facebook_post.dart';
import 'services/facebook_posts_service.dart';

/// Admin view of Facebook page posts (mock data, auto-refresh every 15 minutes).
class FacebookPostsScreen extends StatefulWidget {
  const FacebookPostsScreen({super.key});

  static const Duration refreshInterval = Duration(minutes: 15);

  @override
  State<FacebookPostsScreen> createState() => _FacebookPostsScreenState();
}

class _FacebookPostsScreenState extends State<FacebookPostsScreen> {
  final FacebookPostsService _service = const FacebookPostsService();

  List<FacebookPost> _posts = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _autoRefreshTimer = Timer.periodic(FacebookPostsScreen.refreshInterval, (_) {
      _loadPosts(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPosts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _posts.isEmpty;
        _refreshing = _posts.isNotEmpty;
        _error = null;
      });
    } else {
      setState(() => _refreshing = true);
    }

    try {
      final posts = await _service.fetchMockPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _refreshing = false;
        _lastUpdated = DateTime.now();
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Could not load Facebook posts.';
      });
    }
  }

  String _formatLastUpdated(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[time.month - 1]} ${time.day}, ${time.year} · $hour:$minute $amPm';
  }

  String _formatPostedAgo(DateTime postedAt) {
    final diff = DateTime.now().difference(postedAt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Facebook posts'),
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh now',
              onPressed: _loading ? null : () => _loadPosts(),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadPosts(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _SyncStatusCard(
                        lastUpdated: _lastUpdated,
                        formatLastUpdated: _formatLastUpdated,
                        refreshing: _refreshing,
                      ),
                    ),
                  ),
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _error!,
                              style: textTheme.bodyMedium?.copyWith(color: Colors.orange.shade900),
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: _posts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _FacebookPostCard(
                          post: _posts[index],
                          postedAgo: _formatPostedAgo(_posts[index].postedAt),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.lastUpdated,
    required this.formatLastUpdated,
    required this.refreshing,
  });

  final DateTime? lastUpdated;
  final String Function(DateTime) formatLastUpdated;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: KelseyColors.tealButton.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KelseyColors.tealButton.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.facebook_rounded, color: Color(0xFF1877F2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page feed (mock)',
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastUpdated == null
                        ? 'Not synced yet'
                        : 'Last updated: ${formatLastUpdated(lastUpdated!)}',
                    style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    refreshing
                        ? 'Refreshing…'
                        : 'Auto-refreshes every 15 minutes',
                    style: textTheme.labelMedium?.copyWith(
                      color: KelseyColors.tealButton,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacebookPostCard extends StatelessWidget {
  const _FacebookPostCard({
    required this.post,
    required this.postedAgo,
  });

  final FacebookPost post;
  final String postedAgo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: KelseyColors.tealButton.withValues(alpha: 0.15),
                  child: Text(
                    post.avatarInitial,
                    style: textTheme.titleMedium?.copyWith(
                      color: KelseyColors.tealButton,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.profileName,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.pageName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: KelseyColors.cardMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            ' · $postedAgo',
                            style: textTheme.bodySmall?.copyWith(color: KelseyColors.cardMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded, color: Colors.grey.shade500, size: 22),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(
              post.content,
              style: textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                Icon(Icons.thumb_up_alt_rounded, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 6),
                Text(
                  '${post.likes}',
                  style: textTheme.bodySmall?.copyWith(
                    color: KelseyColors.cardMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.thumb_up_outlined, size: 20, color: Colors.grey.shade700),
                    label: Text(
                      'Like',
                      style: textTheme.labelLarge?.copyWith(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Colors.grey.shade700),
                    label: Text(
                      'Comment',
                      style: textTheme.labelLarge?.copyWith(color: Colors.grey.shade700),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.share_outlined, size: 20, color: Colors.grey.shade700),
                    label: Text(
                      'Share',
                      style: textTheme.labelLarge?.copyWith(color: Colors.grey.shade700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
