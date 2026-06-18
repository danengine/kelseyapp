enum ChatSender { user, bot }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.sentAt,
  });

  final String id;
  final String text;
  final ChatSender sender;
  final DateTime sentAt;

  bool get isBot => sender == ChatSender.bot;
}
