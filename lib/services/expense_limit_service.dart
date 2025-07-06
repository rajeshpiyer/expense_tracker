import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExpenseLimitService extends ChangeNotifier {
  static const String _limitKey = 'expense_limit';
  static const String _enabledKey = 'expense_limit_enabled';
  
  double _monthlyLimit = 5000.0; // Default limit in AED
  bool _isEnabled = false;
  
  double get monthlyLimit => _monthlyLimit;
  bool get isEnabled => _isEnabled;
  
  ExpenseLimitService() {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _monthlyLimit = prefs.getDouble(_limitKey) ?? 5000.0;
      _isEnabled = prefs.getBool(_enabledKey) ?? false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading expense limit settings: $e');
      }
    }
  }
  
  Future<void> setLimit(double limit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_limitKey, limit);
      _monthlyLimit = limit;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving expense limit: $e');
      }
    }
  }
  
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
      _isEnabled = enabled;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error saving expense limit enabled state: $e');
      }
    }
  }
  
  double calculateProgress(double currentExpenses) {
    if (!_isEnabled || _monthlyLimit <= 0) return 0.0;
    return (currentExpenses / _monthlyLimit).clamp(0.0, 1.0);
  }
  
  bool isOverLimit(double currentExpenses) {
    return _isEnabled && currentExpenses > _monthlyLimit;
  }
  
  double getRemainingAmount(double currentExpenses) {
    if (!_isEnabled) return 0.0;
    return (_monthlyLimit - currentExpenses).clamp(0.0, _monthlyLimit);
  }
  
  String getStatusMessage(double currentExpenses) {
    if (!_isEnabled) return 'Expense limit disabled';
    
    final remaining = getRemainingAmount(currentExpenses);
    final progress = calculateProgress(currentExpenses);
    
    if (progress >= 1.0) {
      final overAmount = currentExpenses - _monthlyLimit;
      return 'Over limit by ${overAmount.toStringAsFixed(2)}';
    } else if (progress >= 0.8) {
      return 'Warning: ${remaining.toStringAsFixed(2)} remaining';
    } else {
      return '${remaining.toStringAsFixed(2)} remaining';
    }
  }
  
  String formatLimit(double limit) {
    if (limit >= 1000) {
      return '${(limit / 1000).toStringAsFixed(limit % 1000 == 0 ? 0 : 1)}K AED';
    }
    return '${limit.toStringAsFixed(0)} AED';
  }
}
