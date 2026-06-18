import 'dart:math';

import '../models/facebook_post.dart';

/// Mock Facebook page posts — replace with API integration later.
class FacebookPostsService {
  const FacebookPostsService();

  static final _rng = Random();

  static const _templates = [
    (
      profileName: 'Kelsey Reyes',
      pageName: "Kelsey's Homestay",
      avatarInitial: 'K',
      content:
          'Weekend getaway at Verdon Parc? Our 1-bedroom unit is open for March dates. Message us for early-bird rates.',
    ),
    (
      profileName: 'Kelsey Reyes',
      pageName: "Kelsey's Homestay",
      avatarInitial: 'K',
      content:
          'Thank you to everyone who booked with us this month! Your support keeps our team going. See you on your next stay.',
    ),
    (
      profileName: 'Danilo Eslawan',
      pageName: "Kelsey's Homestay",
      avatarInitial: 'D',
      content:
          'New photos are up for our Davao City listings. Swipe through the album and pick your favorite view.',
    ),
    (
      profileName: 'Kelsey Reyes',
      pageName: "Kelsey's Homestay",
      avatarInitial: 'K',
      content:
          'Travel tip: book at least 2 weeks ahead for holiday weekends. Units near the city center fill up fast.',
    ),
    (
      profileName: 'Maria Santos',
      pageName: "Kelsey's Homestay",
      avatarInitial: 'M',
      content:
          'We just refreshed linens and amenities across all active units. Clean, cozy, and ready for check-in.',
    ),
  ];

  Future<List<FacebookPost>> fetchMockPosts() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final now = DateTime.now();
    return List.generate(_templates.length, (index) {
      final template = _templates[index];
      final baseLikes = 24 + index * 17;
      final jitter = _rng.nextInt(12);

      return FacebookPost(
        id: 'mock-post-$index',
        profileName: template.profileName,
        pageName: template.pageName,
        avatarInitial: template.avatarInitial,
        content: template.content,
        likes: baseLikes + jitter,
        postedAt: now.subtract(Duration(hours: 3 + index * 9)),
      );
    });
  }
}
