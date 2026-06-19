import 'package:flutter/material.dart';

import 'kelsey_brand.dart';
import 'models/chat_message.dart';
import 'models/unit_listing.dart';
import 'services/auth_session.dart';
import 'services/kelsey_chatbot_service.dart';
import 'unit_detail_screen.dart';
import 'utils/chat_location_helper.dart';
import 'utils/chat_unit_parser.dart';
import 'widgets/chat_formatted_text.dart';

/// Chat with Kelsey — friendly in-app homestay assistant (mock replies for now).
class KelseyChatScreen extends StatefulWidget {
  const KelseyChatScreen({super.key});

  @override
  State<KelseyChatScreen> createState() => _KelseyChatScreenState();
}

class _KelseyChatScreenState extends State<KelseyChatScreen> {
  final KelseyChatbotService _chatbot = const KelseyChatbotService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _botTyping = false;
  int _messageCounter = 0;

  @override
  void initState() {
    super.initState();
    _appendBotMessage(_chatbot.welcomeMessage(AuthSession.profile?.firstName));
    ChatLocationHelper.prefetch();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  String _nextId() {
    _messageCounter += 1;
    return 'msg-$_messageCounter';
  }

  void _appendBotMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          id: _nextId(),
          text: text,
          sender: ChatSender.bot,
          sentAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _appendUserMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          id: _nextId(),
          text: text,
          sender: ChatSender.user,
          sentAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _botTyping) return;

    if (!AuthSession.isLoggedIn) {
      _appendUserMessage(text);
      _inputController.clear();
      _appendBotMessage('Please log in to chat with me and get real-time unit recommendations.');
      return;
    }

    _inputController.clear();
    _appendUserMessage(text);

    setState(() => _botTyping = true);
    _scrollToBottom();

    try {
      double? latitude;
      double? longitude;

      if (chatMessageWantsNearMe(text)) {
        final position = await ChatLocationHelper.forNearMeQuery();
        if (position == null) {
          if (!mounted) return;
          setState(() => _botTyping = false);
          _appendBotMessage(
            'I need your location to find stays near you. '
            'Allow location access for Kelsey in Settings, then tap "Units near me" again.',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location is required for nearby unit search.'),
              ),
            );
          }
          return;
        }
        latitude = position.latitude;
        longitude = position.longitude;
      }

      final history = _messages
          .where((m) => m.id != 'welcome')
          .map(
            (m) => (
              role: m.isBot ? 'model' : 'user',
              content: m.text,
            ),
          )
          .toList();

      final reply = await _chatbot.replyTo(
        userMessage: text,
        history: history,
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted) return;
      setState(() => _botTyping = false);
      _appendBotReply(reply);
    } on ChatbotException catch (e) {
      if (!mounted) return;
      setState(() => _botTyping = false);
      _appendBotMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _botTyping = false);
      _appendBotMessage('Sorry, I hit a small snag. Please try again in a moment.');
    }
  }

  void _appendBotReply(ChatbotReply reply) {
    setState(() {
      _messages.add(
        ChatMessage(
          id: _nextId(),
          text: reply.message,
          sender: ChatSender.bot,
          sentAt: DateTime.now(),
          suggestedUnits: reply.suggestedUnits,
        ),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendQuickReply(String text) {
    _inputController.text = text;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: KelseyColors.background,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const KelseyBotAvatar(size: 40, showOnlineDot: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chatbot.botName,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _botTyping ? 'Typing…' : 'Online · Homestay assistant',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_botTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_botTyping && index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _TypingBubble(),
                  );
                }
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: message.isBot
                      ? _BotMessageBubble(message: message)
                      : _UserMessageBubble(message: message),
                );
              },
            ),
          ),
          if (_messages.length <= 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickChip(label: 'How do I book?', onTap: () => _sendQuickReply('How do I book?')),
                  _QuickChip(label: 'Units near me', onTap: () => _sendQuickReply('Find units near my location')),
                  _QuickChip(label: 'Payment options', onTap: () => _sendQuickReply('What payment options are there?')),
                ],
              ),
            ),
          Material(
            elevation: 8,
            shadowColor: Colors.black26,
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message Kelsey…',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        filled: true,
                        fillColor: const Color(0xFFF4F6F5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: KelseyColors.tealButton,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _botTyping ? null : _sendMessage,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly bot face used in the app bar and message bubbles.
class KelseyBotAvatar extends StatelessWidget {
  const KelseyBotAvatar({
    super.key,
    this.size = 36,
    this.showOnlineDot = false,
    this.compact = false,
  });

  final double size;
  final bool showOnlineDot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final borderWidth = compact ? 1.5 : 2.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                KelseyColors.yellow,
                KelseyColors.yellow.withValues(alpha: 0.88),
              ],
            ),
            border: Border.all(color: Colors.white, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: KelseyColors.tealButton.withValues(alpha: 0.18),
                blurRadius: compact ? 6 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.sentiment_very_satisfied_rounded,
            color: KelseyColors.tealButton,
            size: size * 0.56,
          ),
        ),
        if (showOnlineDot)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Profile screen entry card for opening the chatbot.
class ProfileChatEntryCard extends StatelessWidget {
  const ProfileChatEntryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: KelseyColors.tealButton.withValues(alpha: 0.14)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                KelseyColors.background.withValues(alpha: 0.04),
                Colors.white,
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const KelseyBotAvatar(size: 52, showOnlineDot: true, compact: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHAT WITH KELSEY',
                      style: textTheme.labelSmall?.copyWith(
                        color: KelseyColors.tealButton,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your homestay assistant',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask about bookings, stays, or payments',
                      style: textTheme.bodySmall?.copyWith(
                        color: KelseyColors.cardMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KelseyColors.tealButton,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: KelseyColors.tealButton.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.chat_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating entry point to open the chat screen.
class KelseyChatLauncherButton extends StatelessWidget {
  const KelseyChatLauncherButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 10,
      shadowColor: KelseyColors.background.withValues(alpha: 0.22),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: KelseyColors.adminTeal.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KelseyBotAvatar(size: 46, showOnlineDot: true, compact: true),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelsey',
                    style: textTheme.titleSmall?.copyWith(
                      color: KelseyColors.adminTeal,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ask me anything',
                    style: textTheme.labelMedium?.copyWith(
                      color: KelseyColors.cardMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotMessageBubble extends StatelessWidget {
  const _BotMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const KelseyBotAvatar(size: 32),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(color: KelseyColors.tealButton.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ChatFormattedText(
                  text: message.text,
                  style: textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
              ),
              if (message.suggestedUnits.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...message.suggestedUnits.map(
                  (unit) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChatUnitPreviewCard(unit: unit),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatUnitPreviewCard extends StatelessWidget {
  const _ChatUnitPreviewCard({required this.unit});

  final UnitListing unit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => UnitDetailScreen(unit: unit)),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: KelseyColors.adminTeal.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: unit.mainImageUrl.isNotEmpty
                    ? Image.network(
                        unit.mainImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _thumbFallback(),
                      )
                    : _thumbFallback(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit.priceLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: KelseyColors.adminTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right_rounded, color: KelseyColors.adminTeal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return ColoredBox(
      color: KelseyColors.adminSurface,
      child: Icon(Icons.home_outlined, color: Colors.grey.shade400),
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: KelseyColors.tealButton,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              message.text,
              style: textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const KelseyBotAvatar(size: 32),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: KelseyColors.tealButton.withValues(alpha: 0.12)),
          ),
          child: const _TypingDots(),
        ),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = (_controller.value + delay) % 1.0;
            final opacity = 0.35 + (t < 0.5 ? t * 1.3 : (1 - t) * 1.3);
            return Padding(
              padding: EdgeInsets.only(right: index < 2 ? 6 : 0),
              child: Opacity(
                opacity: opacity.clamp(0.35, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: KelseyColors.tealButton,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(color: KelseyColors.tealButton.withValues(alpha: 0.35)),
      labelStyle: const TextStyle(
        color: KelseyColors.tealButton,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
