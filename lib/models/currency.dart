enum Currency {
  aed('AED', 'د.إ', 'UAE Dirham'),
  usd('USD', '\$', 'US Dollar'),
  inr('INR', '₹', 'Indian Rupee');

  const Currency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;

  static Currency fromCode(String code) {
    return Currency.values.firstWhere(
      (currency) => currency.code == code,
      orElse: () => Currency.aed,
    );
  }
}
