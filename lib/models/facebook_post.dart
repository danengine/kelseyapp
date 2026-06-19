class FacebookPost {
  const FacebookPost({
    required this.id,
    required this.profileName,
    required this.pageName,
    required this.avatarInitial,
    required this.content,
    required this.likes,
    this.postedAt,
    this.postedAtLabel,
    this.comments,
    this.postUrl,
    this.commentsUrl,
  });

  final String id;
  final String profileName;
  final String pageName;
  final String avatarInitial;
  final String content;
  final int likes;
  final DateTime? postedAt;
  final String? postedAtLabel;
  final int? comments;
  final String? postUrl;
  final String? commentsUrl;

  bool get hasPostLink => postUrl != null && postUrl!.trim().isNotEmpty;
  bool get hasCommentsLink => commentsUrl != null && commentsUrl!.trim().isNotEmpty;

  factory FacebookPost.fromJson(Map<String, dynamic> json) {
    final profileName = json['profileName'] as String? ?? 'Unknown';
    final postedRaw = json['postedAt'];
    final postedAtLabel = json['postedAtLabel'] as String?;
    final postUrl = json['postUrl'] as String?;
    final commentsUrl = json['commentsUrl'] as String?;

    return FacebookPost(
      id: json['id'] as String? ?? 'fb-${profileName.hashCode}',
      profileName: profileName,
      pageName: json['pageName'] as String? ?? 'Facebook',
      avatarInitial: json['avatarInitial'] as String? ??
          (profileName.isNotEmpty ? profileName[0].toUpperCase() : '?'),
      content: json['content'] as String? ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt(),
      postedAt: _parsePostedAt(postedRaw),
      postedAtLabel: postedAtLabel,
      postUrl: postUrl,
      commentsUrl: commentsUrl ?? postUrl,
    );
  }

  static DateTime? _parsePostedAt(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.isEmpty) return null;

    if (raw is String) {
      final iso = DateTime.tryParse(raw);
      if (iso != null) return iso.toLocal();

      final relative = _parseRelativeLabel(raw);
      if (relative != null) return relative;
    }

    return null;
  }

  static DateTime? _parseRelativeLabel(String raw) {
    final text = raw.trim().toLowerCase();
    if (text == 'just now' || text == 'now') return DateTime.now();

    final patterns = <RegExp, Duration Function(int)>{
      RegExp(r'^(\d+)\s*m(in|ins|inutes?)?$'): (v) => Duration(minutes: v),
      RegExp(r'^(\d+)\s*h(r|rs|ours?)?$'): (v) => Duration(hours: v),
      RegExp(r'^(\d+)\s*d(ays?)?$'): (v) => Duration(days: v),
      RegExp(r'^(\d+)m$'): (v) => Duration(minutes: v),
      RegExp(r'^(\d+)h$'): (v) => Duration(hours: v),
      RegExp(r'^(\d+)d$'): (v) => Duration(days: v),
    };

    for (final entry in patterns.entries) {
      final match = entry.key.firstMatch(text);
      if (match != null) {
        final value = int.tryParse(match.group(1)!);
        if (value == null) continue;
        return DateTime.now().subtract(entry.value(value));
      }
    }

    if (text == 'yesterday') {
      return DateTime.now().subtract(const Duration(days: 1));
    }

    return null;
  }

  String get displayTimeLabel {
    if (postedAt != null) return _formatAgo(postedAt!);
    if (postedAtLabel != null && postedAtLabel!.trim().isNotEmpty) {
      return postedAtLabel!.trim();
    }
    return 'Recently';
  }

  static String _formatAgo(DateTime postedAt) {
    final diff = DateTime.now().difference(postedAt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  FacebookPost copyWith({int? likes}) {
    return FacebookPost(
      id: id,
      profileName: profileName,
      pageName: pageName,
      avatarInitial: avatarInitial,
      content: content,
      likes: likes ?? this.likes,
      postedAt: postedAt,
      postedAtLabel: postedAtLabel,
      comments: comments,
      postUrl: postUrl,
      commentsUrl: commentsUrl,
    );
  }
}
