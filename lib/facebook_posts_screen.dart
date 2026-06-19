import 'dart:async';

import 'package:flutter/material.dart';

import 'kelsey_brand.dart';
import 'models/facebook_post.dart';
import 'services/auth_service.dart';
import 'services/facebook_posts_service.dart';
import 'utils/external_url.dart';
import 'widgets/linkified_text.dart';

/// Admin view of Facebook "looking for" posts scraped from search (auto-refresh every 15 minutes).
class FacebookPostsScreen extends StatefulWidget {
  const FacebookPostsScreen({super.key});

  static const Duration refreshInterval = Duration(minutes: 15);

  @override
  State<FacebookPostsScreen> createState() => _FacebookPostsScreenState();
}

class _FacebookPostsScreenState extends State<FacebookPostsScreen> {
  static const _teal = KelseyColors.adminTeal;

  final FacebookPostsService _service = const FacebookPostsService();

  List<FacebookPost> _posts = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _selectionMode = false;
  bool _bulkDeleting = false;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _autoRefreshTimer;
  final Set<String> _selectedIds = {};
  final Set<String> _deletingIds = {};

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

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(_posts.map((post) => post.id));
    });
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
      final posts = await _service.fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _refreshing = false;
        _lastUpdated = DateTime.now();
        _error = null;
        _selectedIds.removeWhere((id) => posts.every((post) => post.id != id));
        if (_selectedIds.isEmpty && _selectionMode && posts.isEmpty) {
          _selectionMode = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e is AuthException ? e.message : 'Could not load Facebook posts.';
      });
    }
  }

  Future<void> _confirmDeletePosts(List<String> ids) async {
    if (ids.isEmpty) return;

    final count = ids.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $count post${count == 1 ? '' : 's'}?'),
        content: Text(
          count == 1
              ? 'This post will be hidden from the list and won\'t be added again on refresh.'
              : 'These posts will be hidden from the list and won\'t be added again on refresh.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KelseyColors.adminBadgeRed),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove $count'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _bulkDeleting = ids.length > 1;
      _deletingIds.addAll(ids);
    });

    try {
      await _service.deletePosts(ids);
      if (!mounted) return;
      setState(() {
        _posts = _posts.where((item) => !ids.contains(item.id)).toList();
        _selectedIds.removeAll(ids);
        _deletingIds.removeAll(ids);
        _bulkDeleting = false;
        if (_selectedIds.isEmpty) _selectionMode = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed $count post${count == 1 ? '' : 's'}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deletingIds.removeAll(ids);
        _bulkDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AuthException ? e.message : 'Could not remove posts.'),
        ),
      );
    }
  }

  Future<void> _openUrl(BuildContext context, String? url, {required String failureMessage}) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
      return;
    }
    final opened = await openExternalUrl(url);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  String _formatLastUpdated(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[time.month - 1]} ${time.day}, ${time.year} · $hour:$minute $amPm';
  }

  String _formatPostedAgo(FacebookPost post) => post.displayTimeLabel;

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      final allSelected = _posts.isNotEmpty && _selectedIds.length == _posts.length;
      return AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _teal,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Cancel selection',
          onPressed: _bulkDeleting ? null : _exitSelectionMode,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text('${_selectedIds.length} selected'),
        actions: [
          TextButton(
            onPressed: _bulkDeleting || _posts.isEmpty
                ? null
                : () {
                    if (allSelected) {
                      setState(_selectedIds.clear);
                    } else {
                      _selectAllVisible();
                    }
                  },
            child: Text(allSelected ? 'Clear all' : 'Select all'),
          ),
          IconButton(
            tooltip: 'Remove selected',
            onPressed: _bulkDeleting || _selectedIds.isEmpty
                ? null
                : () => _confirmDeletePosts(_selectedIds.toList()),
            icon: _bulkDeleting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: KelseyColors.adminBadgeRed),
                  )
                : const Icon(Icons.delete_outline_rounded, color: KelseyColors.adminBadgeRed),
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('Facebook posts'),
      backgroundColor: Colors.white,
      foregroundColor: _teal,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (_posts.isNotEmpty)
          IconButton(
            tooltip: 'Select posts',
            onPressed: _loading ? null : _toggleSelectionMode,
            icon: const Icon(Icons.checklist_rounded),
          ),
        if (_refreshing)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _teal),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: KelseyColors.adminSurface,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : RefreshIndicator(
              color: _teal,
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
                        postCount: _posts.length,
                        selectionMode: _selectionMode,
                        selectedCount: _selectedIds.length,
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
                  if (_posts.isEmpty && _error == null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No posts yet. The scraper refreshes every 15 minutes — pull down to check again.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(color: KelseyColors.cardMuted),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, _selectionMode && _selectedIds.isNotEmpty ? 96 : 24),
                      sliver: SliverList.separated(
                        itemCount: _posts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          final isSelected = _selectedIds.contains(post.id);
                          return _FacebookPostCard(
                            post: post,
                            postedAgo: _formatPostedAgo(post),
                            selectionMode: _selectionMode,
                            isSelected: isSelected,
                            isDeleting: _deletingIds.contains(post.id),
                            onTap: _selectionMode
                                ? () => _toggleSelected(post.id)
                                : null,
                            onLongPress: !_selectionMode ? _toggleSelectionMode : null,
                            onDelete: _selectionMode ? null : () => _confirmDeletePosts([post.id]),
                            onOpenPost: !_selectionMode && post.hasPostLink
                                ? () => _openUrl(
                                      context,
                                      post.postUrl,
                                      failureMessage: 'Could not open this post on Facebook.',
                                    )
                                : null,
                            onOpenComments: !_selectionMode && post.hasCommentsLink
                                ? () => _openUrl(
                                      context,
                                      post.commentsUrl,
                                      failureMessage: 'Could not open comments on Facebook.',
                                    )
                                : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: KelseyColors.adminBadgeRed,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _bulkDeleting ? null : () => _confirmDeletePosts(_selectedIds.toList()),
                  icon: _bulkDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: Text('Remove ${_selectedIds.length} selected'),
                ),
              ),
            )
          : null,
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.lastUpdated,
    required this.formatLastUpdated,
    required this.refreshing,
    required this.postCount,
    required this.selectionMode,
    required this.selectedCount,
  });

  final DateTime? lastUpdated;
  final String Function(DateTime) formatLastUpdated;
  final bool refreshing;
  final int postCount;
  final bool selectionMode;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: KelseyColors.adminTeal.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KelseyColors.adminTeal.withValues(alpha: 0.1),
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
                    'Looking for: airbnb',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KelseyColors.adminTeal,
                    ),
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
                    selectionMode
                        ? '$selectedCount of $postCount selected'
                        : refreshing
                            ? 'Refreshing…'
                            : '$postCount posts · newest first · auto-refresh every 15 min',
                    style: textTheme.labelMedium?.copyWith(
                      color: KelseyColors.adminTeal,
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
    required this.selectionMode,
    required this.isSelected,
    required this.isDeleting,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onOpenPost,
    this.onOpenComments,
  });

  final FacebookPost post;
  final String postedAgo;
  final bool selectionMode;
  final bool isSelected;
  final bool isDeleting;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenPost;
  final VoidCallback? onOpenComments;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: isSelected ? KelseyColors.adminTeal.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? KelseyColors.adminTeal.withValues(alpha: 0.45)
              : KelseyColors.adminTeal.withValues(alpha: 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(selectionMode ? 8 : 14, 14, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 4),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: isDeleting ? null : (_) => onTap?.call(),
                        activeColor: KelseyColors.adminTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: KelseyColors.adminTeal.withValues(alpha: 0.12),
                    child: Text(
                      post.avatarInitial,
                      style: textTheme.titleMedium?.copyWith(
                        color: KelseyColors.adminTeal,
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
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
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
                  if (!selectionMode)
                    if (isDeleting)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: KelseyColors.adminTeal),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: 'Remove post',
                        onPressed: onDelete,
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade600),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: LinkifiedText(
                text: post.content,
                style: textTheme.bodyLarge?.copyWith(height: 1.45, color: const Color(0xFF374151)),
              ),
            ),
            if (onOpenPost != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenPost,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('View on Facebook'),
                    style: TextButton.styleFrom(
                      foregroundColor: KelseyColors.adminTeal,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: KelseyColors.adminSurface,
                border: Border(
                  top: BorderSide(color: KelseyColors.adminTeal.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  _EngagementChip(
                    icon: Icons.thumb_up_alt_rounded,
                    label: '${post.likes}',
                    caption: post.likes == 1 ? 'like' : 'likes',
                  ),
                  const SizedBox(width: 12),
                  _EngagementChip(
                    icon: Icons.chat_bubble_rounded,
                    label: '${post.comments ?? 0}',
                    caption: (post.comments ?? 0) == 1 ? 'comment' : 'comments',
                    onTap: onOpenComments,
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

class _EngagementChip extends StatelessWidget {
  const _EngagementChip({
    required this.icon,
    required this.label,
    required this.caption,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KelseyColors.adminTeal.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: KelseyColors.adminTeal),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: KelseyColors.adminTeal,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            caption,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.open_in_new_rounded, size: 12, color: Colors.grey.shade500),
          ],
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}
