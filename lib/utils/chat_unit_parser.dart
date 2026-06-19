/// Parse `[unit:123]` tags from AI replies (numeric unit ids).
List<String> parseUnitIdsFromChatMessage(String message) {
  final pattern = RegExp(r'\[unit:\s*(\d+)\s*\]', caseSensitive: false);
  final ids = <String>{};
  for (final match in pattern.allMatches(message)) {
    final id = match.group(1);
    if (id != null && id.isNotEmpty) ids.add(id);
  }
  return ids.toList();
}

/// Display text with `[unit:id]` tags removed. Preserves line breaks for lists.
String stripUnitTagsFromChatMessage(String message) {
  var result = message.replaceAll(RegExp(r'\[unit:\s*\d+\s*\]', caseSensitive: false), '');
  result = result
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trimRight())
      .join('\n');
  result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return result.trim();
}

/// Inserts line breaks before inline numbered/bullet list items.
String normalizeChatMessageDisplay(String message) {
  var text = message.trim();
  text = text.replaceAllMapped(RegExp(r'(?<=\S)\s+(?=\d+\.\s)'), (_) => '\n');
  text = text.replaceAllMapped(RegExp(r'(?<=\S)\s+(?=[-•*]\s)'), (_) => '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text;
}

bool chatMessageWantsNearMe(String text) {
  final lower = text.toLowerCase();
  return RegExp(r'near\s*(me|my\s*location|my\s*area|by)').hasMatch(lower) ||
      RegExp(r'\bnearby\b').hasMatch(lower) ||
      RegExp(r'around\s*here').hasMatch(lower) ||
      RegExp(r'close\s*to\s*me').hasMatch(lower) ||
      RegExp(r'units?\s+near').hasMatch(lower) ||
      RegExp(r'(find|show|list|get).{0,20}near').hasMatch(lower) ||
      RegExp(r'\bclosest\b').hasMatch(lower);
}

bool chatMessageWantsLocationSearch(String text) {
  final lower = text.trim().toLowerCase();
  if (lower.isEmpty) return false;
  return RegExp(r'\bnear\s+[a-z]').hasMatch(lower) ||
      RegExp(r'\bin\s+[a-z]').hasMatch(lower) ||
      RegExp(r'\baround\s+[a-z]').hasMatch(lower) ||
      RegExp(r'\bat\s+[a-z]').hasMatch(lower) ||
      RegExp(r'\b(davao|manila|cebu|taguig|makati|quezon|boracay|palawan|baguio|iloilo|bacolod)\b').hasMatch(lower);
}

/// True when the user is asking to find, browse, or get recommendations for stays.
bool chatMessageWantsUnitRecommendations(String text) {
  final lower = text.trim().toLowerCase();
  if (lower.isEmpty) return false;

  if (chatMessageWantsNearMe(text)) return true;
  if (chatMessageWantsLocationSearch(text)) return true;

  if (RegExp(r'^(hi|hello|hey|thanks|thank you|salamat|bye|goodbye)\b').hasMatch(lower)) {
    return false;
  }

  if (RegExp(r'\b(my bookings?|my points|my rewards|rewards points|how many points|points balance|points do i have)\b').hasMatch(lower)) {
    return false;
  }

  if (RegExp(r'\b(how do i|how to)\s+(book|pay|cancel|refund|check)\b').hasMatch(lower) &&
      !RegExp(r'\b(find|show|recommend|suggest|list|search|available|unit|stay|listing)\b').hasMatch(lower)) {
    return false;
  }

  if (RegExp(r'\b(payment|gcash|bank transfer|refund|cancel|policy|terms and conditions)\b').hasMatch(lower) &&
      !RegExp(r'\b(find|show|recommend|suggest|list|search|unit|stay|listing|apartment|condo|near|nearby)\b').hasMatch(lower)) {
    return false;
  }

  return RegExp(
    r'\b(recommend|suggest|show me|find|list|search|browse|looking for|available|options?)\b',
  ).hasMatch(lower) ||
      RegExp(r'\b(units?|listings?|stays?|apartments?|condos?|properties|places? to stay)\b').hasMatch(lower) ||
      RegExp(r'\bwhere can i stay\b').hasMatch(lower) ||
      RegExp(r'\b(cheapest|budget|affordable)\b').hasMatch(lower) ||
      RegExp(r'\b\d+\s*[-]?\s*bed(room)?').hasMatch(lower);
}
