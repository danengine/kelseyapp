import 'dart:math';

/// Friendly mock replies for the in-app chatbot (replace with API later).
class KelseyChatbotService {
  const KelseyChatbotService();

  static final _rng = Random();

  static const _botName = 'Kelsey';

  String get botName => _botName;

  String welcomeMessage(String? userName) {
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) {
      return "Hi $name! I'm Kelsey, your homestay buddy. Ask me about stays, bookings, or how to find a place near you.";
    }
    return "Hi there! I'm Kelsey, your homestay buddy. Ask me about stays, bookings, or how to find a place near you.";
  }

  Future<String> replyTo(String userMessage) async {
    final text = userMessage.trim().toLowerCase();
    await Future<void>.delayed(Duration(milliseconds: 500 + _rng.nextInt(700)));

    if (_matches(text, ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening'])) {
      return _pick([
        "Hello! Lovely to meet you. How can I help with your stay today?",
        "Hey! I'm here whenever you need a hand with bookings or finding a unit.",
      ]);
    }

    if (_matches(text, ['book', 'booking', 'reserve', 'reservation'])) {
      return _pick([
        "To book a stay, open any unit from Home, tap Select dates, then follow the payment steps. Your booking will show up under the Bookings tab.",
        "Pick a listing you like, choose your check-in and check-out dates, and complete payment. I'll cheer you on from here!",
      ]);
    }

    if (_matches(text, ['cancel', 'cancelled', 'refund'])) {
      return "For cancellations or refunds, our team reviews each reservation. Check your booking details for the latest status, or reach out to support with your reference code.";
    }

    if (_matches(text, ['map', 'near', 'location', 'where', 'condo'])) {
      return "Tap Open map on Home to see units near you. We sort stays by distance when location is enabled — handy for finding the closest condo.";
    }

    if (_matches(text, ['price', 'cost', 'payment', 'gcash', 'pay'])) {
      return "Prices are shown per night on each listing. When you book, you can pay via GCash or bank transfer. The total appears before you confirm.";
    }

    if (_matches(text, ['thank', 'thanks', 'salamat'])) {
      return _pick([
        "You're very welcome! Happy to help anytime.",
        "Anytime! Enjoy planning your stay.",
      ]);
    }

    if (_matches(text, ['bye', 'goodbye', 'see you'])) {
      return "Goodbye for now! Come back if you need anything else. Have a wonderful day!";
    }

    return _pick([
      "I'm still learning, but I can help with bookings, maps, payments, and finding a stay. What would you like to know?",
      "Great question! Try asking about bookings, nearby units, or how payments work — I'm happy to guide you.",
      "I'm here for homestay questions — listings, dates, or the Bookings tab. What can I help with?",
    ]);
  }

  bool _matches(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _pick(List<String> options) => options[_rng.nextInt(options.length)];
}
