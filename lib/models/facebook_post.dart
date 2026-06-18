class FacebookPost {
  const FacebookPost({
    required this.id,
    required this.profileName,
    required this.pageName,
    required this.avatarInitial,
    required this.content,
    required this.likes,
    required this.postedAt,
  });

  final String id;
  final String profileName;
  final String pageName;
  final String avatarInitial;
  final String content;
  final int likes;
  final DateTime postedAt;

  FacebookPost copyWith({int? likes}) {
    return FacebookPost(
      id: id,
      profileName: profileName,
      pageName: pageName,
      avatarInitial: avatarInitial,
      content: content,
      likes: likes ?? this.likes,
      postedAt: postedAt,
    );
  }
}
