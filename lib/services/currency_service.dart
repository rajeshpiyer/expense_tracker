import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';

class CurrencyService extends ChangeNotifier {
  Currency _selectedCurrency = Currency.aed;
  static const String _currencyKey = 'selected_currency';

  Currency get selectedCurrency => _selectedCurrency;

  CurrencyService() {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final currencyCode = prefs.getString(_currencyKey) ?? Currency.aed.code;
    _selectedCurrency = Currency.fromCode(currencyCode);
    notifyListeners();
  }

  Future<void> setCurrency(Currency currency) async {
    _selectedCurrency = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currency.code);
    notifyListeners();
  }

  String formatAmount(double amount) {
    return '${_selectedCurrency.symbol}${amount.toStringAsFixed(2)}';
  }
}
