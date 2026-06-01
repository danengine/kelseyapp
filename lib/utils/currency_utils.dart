/// Philippine peso formatting for prices shown in the app.
class CurrencyUtils {
  CurrencyUtils._();

  static const String pesoSymbol = '₱';

  /// Maps `$`, `USD`, `PHP`, etc. to the peso sign.
  static String normalizeSymbol(String? currency) {
    if (currency == null || currency.trim().isEmpty) return pesoSymbol;
    final normalized = currency.trim().toUpperCase();
    switch (normalized) {
      case '\$':
      case 'USD':
      case 'PHP':
      case '₱':
        return pesoSymbol;
      default:
        return currency.trim();
    }
  }

  static String formatAmount(
    num amount, {
    String? currency,
    bool decimals = false,
  }) {
    final symbol = normalizeSymbol(currency);
    final value = decimals ? amount.toDouble().toStringAsFixed(2) : amount.toDouble().toStringAsFixed(0);
    return '$symbol$value';
  }

  static String formatPerNight(num amount, {String? currency}) {
    return '${formatAmount(amount, currency: currency)}/night';
  }
}
