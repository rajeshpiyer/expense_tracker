import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../database/database_helper.dart';

class JsonImportService {
  static const String _importStatusKey = 'initial_data_imported';
  static const String _targetUser = 'prajeshiyer@gmail.com';
  
  /// Import initial expenses for specific user if no transactions exist
  Future<bool> importInitialDataIfNeeded(String userEmail) async {
    try {
      // Only import for target user
      if (userEmail != _targetUser) {
        print('JsonImportService: User $userEmail is not target user, skipping import');
        return false;
      }
      
      // Check if already imported
      final prefs = await SharedPreferences.getInstance();
      bool alreadyImported = prefs.getBool(_importStatusKey) ?? false;
      
      if (alreadyImported) {
        print('JsonImportService: Initial data already imported, skipping');
        return false;
      }
      
      // Check if there are existing transactions
      final dbHelper = DatabaseHelper();
      final existingTransactions = await dbHelper.getTransactions(_targetUser);
      
      if (existingTransactions.isNotEmpty) {
        print('JsonImportService: Existing transactions found (${existingTransactions.length}), skipping import');
        // Mark as imported to avoid future checks
        await prefs.setBool(_importStatusKey, true);
        return false;
      }
      
      print('JsonImportService: No existing transactions, importing initial data...');
      
      // Load and parse JSON file
      final jsonString = await rootBundle.loadString('assets/data/initial_expenses.json');
      final jsonData = json.decode(jsonString);
      
      if (jsonData['transactions'] == null) {
        print('JsonImportService: No transactions found in JSON file');
        return false;
      }
      
      List<dynamic> transactionsList = jsonData['transactions'];
      int importedCount = 0;
      int errorCount = 0;
      
      print('JsonImportService: Found ${transactionsList.length} transactions to import');
      
      for (var transactionData in transactionsList) {
        try {
          final transaction = _parseJsonToTransaction(transactionData, userEmail);
          if (transaction != null) {
            await dbHelper.insertTransaction(transaction);
            importedCount++;
          }
        } catch (e) {
          print('JsonImportService: Error importing transaction: $e');
          errorCount++;
        }
      }
      
      // Mark as imported
      await prefs.setBool(_importStatusKey, true);
      
      print('JsonImportService: Import completed - $importedCount imported, $errorCount errors');
      
      return importedCount > 0;
      
    } catch (e) {
      print('JsonImportService: Error during import: $e');
      return false;
    }
  }
  
  /// Parse JSON transaction data to Transaction model
  Transaction? _parseJsonToTransaction(Map<String, dynamic> data, String userId) {
    try {
      final dateStr = data['date']?.toString();
      final description = data['description']?.toString();
      final amount = data['amount'];
      final category = data['category']?.toString();
      final type = data['type']?.toString();
      
      if (dateStr == null || description == null || amount == null || 
          category == null || type == null) {
        print('JsonImportService: Missing required fields in transaction data');
        return null;
      }
      
      // Parse date
      DateTime? date = _parseDate(dateStr);
      if (date == null) {
        print('JsonImportService: Invalid date format: $dateStr');
        return null;
      }
      
      // Parse amount
      double parsedAmount;
      if (amount is int) {
        parsedAmount = amount.toDouble();
      } else if (amount is double) {
        parsedAmount = amount;
      } else if (amount is String) {
        parsedAmount = double.tryParse(amount) ?? 0.0;
      } else {
        print('JsonImportService: Invalid amount format: $amount');
        return null;
      }
      
      // Validate category
      if (!_isValidCategory(category, type)) {
        print('JsonImportService: Invalid category $category for type $type');
        return null;
      }
      
      // Convert string type to TransactionType enum
      TransactionType transactionType;
      if (type == 'income') {
        transactionType = TransactionType.income;
      } else if (type == 'expense') {
        transactionType = TransactionType.expense;
      } else {
        print('JsonImportService: Invalid transaction type: $type');
        return null;
      }

      return Transaction(
        userId: userId,
        date: date,
        description: description,
        amount: parsedAmount,
        category: category,
        type: transactionType,
        createdAt: DateTime.now(),
      );
      
    } catch (e) {
      print('JsonImportService: Error parsing transaction: $e');
      return null;
    }
  }
  
  /// Parse date string to DateTime
  DateTime? _parseDate(String dateStr) {
    try {
      // Expected format: YYYY-MM-DD
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
        return DateTime.parse(dateStr);
      }
      
      // Try other formats if needed
      if (dateStr.contains('/')) {
        var parts = dateStr.split('/');
        if (parts.length == 3) {
          // Try MM/DD/YYYY
          int month = int.parse(parts[0]);
          int day = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Validate category against predefined lists
  bool _isValidCategory(String category, String type) {
    const expenseCategories = ['Food', 'Groceries', 'Purchase', 'Travel', 'Entertainment', 'Other'];
    const incomeCategories = ['Salary', 'Per Diem', 'Bonus', 'Advance', 'Other'];
    
    if (type == 'expense') {
      return expenseCategories.contains(category);
    } else if (type == 'income') {
      return incomeCategories.contains(category);
    }
    
    return false;
  }
  
  /// Reset import status (for testing purposes)
  Future<void> resetImportStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_importStatusKey);
    print('JsonImportService: Import status reset');
  }
  
  /// Check if initial data has been imported
  Future<bool> isInitialDataImported() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_importStatusKey) ?? false;
  }
  
  /// Get import metadata from JSON file
  Future<Map<String, dynamic>?> getImportMetadata() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/initial_expenses.json');
      final jsonData = json.decode(jsonString);
      return jsonData['metadata'];
    } catch (e) {
      print('JsonImportService: Error loading metadata: $e');
      return null;
    }
  }
}
