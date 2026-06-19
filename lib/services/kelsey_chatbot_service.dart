import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/unit_listing.dart';
import '../utils/chat_unit_parser.dart';
import 'auth_session.dart';

class ChatbotReply {
  const ChatbotReply({
    required this.message,
    this.suggestedUnits = const [],
  });

  final String message;
  final List<UnitListing> suggestedUnits;
}

class ChatbotException implements Exception {
  ChatbotException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Calls the kelseybackend chatbot API (Groq + live unit data from auth).
class KelseyChatbotService {
  const KelseyChatbotService();

  static const _botName = 'Kelsey';

  String get botName => _botName;

  String welcomeMessage(String? userName) {
    if (!AuthSession.isLoggedIn) {
      return "Hi! I'm Kelsey. Log in to ask about available stays, nearby units, and bookings.";
    }
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) {
      return "Hi $name! I'm Kelsey. Ask me to find units, suggest stays near you, or help with bookings.";
    }
    return "Hi! I'm Kelsey. Ask me to find units, suggest stays near you, or help with bookings.";
  }

  Future<ChatbotReply> replyTo({
    required String userMessage,
    required List<({String role, String content})> history,
    double? latitude,
    double? longitude,
  }) async {
    final token = AuthSession.accessToken;
    if (token == null || token.isEmpty) {
      throw ChatbotException('Please log in to chat with Kelsey.');
    }

    final body = <String, dynamic>{
      'message': userMessage.trim(),
      'history': history
          .map((entry) => {'role': entry.role, 'content': entry.content})
          .toList(),
    };

    if (latitude != null && longitude != null) {
      body['latitude'] = latitude;
      body['longitude'] = longitude;
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(ApiConfig.chatbotChatUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw ChatbotException(
        'Could not reach the chatbot at ${ApiConfig.chatbotBaseUrl}. '
        'Ensure kelseybackend/chatbot is running (docker compose up).',
      );
    }

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      payload = null;
    }

    if (response.statusCode == 401) {
      throw ChatbotException('Your session expired. Please log in again.');
    }

    if (response.statusCode == 503) {
      final err = payload?['error'] as String?;
      throw ChatbotException(
        err ?? 'Chatbot is unavailable. Check that GROQ_API_KEY is set on the server.',
      );
    }

    if (response.statusCode != 200) {
      final err = payload?['error'] as String? ?? 'Chat request failed (${response.statusCode}).';
      throw ChatbotException(err);
    }

    final rawMessage = payload?['message'] as String? ?? '';
    final unitsJson = payload?['units'];
    final units = unitsJson is List
        ? unitsJson
            .whereType<Map>()
            .map((item) => UnitListing.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <UnitListing>[];

    final suggestedJson = payload?['suggestedUnits'];
    List<UnitListing> parsedUnits;
    if (suggestedJson is List && suggestedJson.isNotEmpty) {
      parsedUnits = suggestedJson
          .whereType<Map>()
          .map((item) => UnitListing.fromJson(Map<String, dynamic>.from(item)))
          .where((unit) => unit.id.isNotEmpty)
          .toList();
    } else {
      final unitIds = parseUnitIdsFromChatMessage(rawMessage);
      parsedUnits = unitIds
          .map((id) {
            for (final unit in units) {
              if (unit.id == id) return unit;
            }
            return null;
          })
          .whereType<UnitListing>()
          .toList();
    }

    final wantsRecommendations = chatMessageWantsUnitRecommendations(userMessage);
    final hasTaggedUnits = parseUnitIdsFromChatMessage(rawMessage).isNotEmpty;

    return ChatbotReply(
      message: stripUnitTagsFromChatMessage(rawMessage).isNotEmpty
          ? stripUnitTagsFromChatMessage(rawMessage)
          : rawMessage.trim(),
      suggestedUnits: (wantsRecommendations || hasTaggedUnits || parsedUnits.isNotEmpty)
          ? parsedUnits
          : const [],
    );
  }
}
