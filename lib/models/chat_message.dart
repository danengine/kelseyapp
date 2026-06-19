import '../models/unit_listing.dart';

enum ChatSender { user, bot }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.sentAt,
    this.suggestedUnits = const [],
  });

  final String id;
  final String text;
  final ChatSender sender;
  final DateTime sentAt;
  final List<UnitListing> suggestedUnits;

  bool get isBot => sender == ChatSender.bot;
}
