import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/transaction.dart';

class ExcelImportService {
  static const String _importedKey = 'excel_data_imported';
  static const String _targetEmail = 'prajeshiyer@gmail.com';
  
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// Check if data has already been imported for the user
  Future<bool> hasDataBeenImported() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_importedKey) ?? false;
  }

  /// Mark data as imported
  Future<void> markDataAsImported() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_importedKey, true);
  }

  /// Import expenses from Excel file for specific user
  Future<bool> importExpensesForUser(String userEmail, String userId) async {
    // Only import for the specific email
    if (userEmail != _targetEmail) {
      if (kDebugMode) {
        print('Excel import skipped - not target user: $userEmail');
      }
      return false;
    }

    // Check if already imported
    if (await hasDataBeenImported()) {
      if (kDebugMode) {
        print('Excel data already imported for user: $userEmail');
      }
      return false;
    }

    try {
      // Load Excel file from assets
      final ByteData data = await rootBundle.load('assets/data/expenses.xlsx');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Parse Excel file
      final excel = Excel.decodeBytes(bytes);
      
      if (excel.tables.isEmpty) {
        if (kDebugMode) {
          print('No sheets found in Excel file');
        }
        return false;
      }

      // Get the first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        if (kDebugMode) {
          print('Sheet is null');
        }
        return false;
      }

      int importedCount = 0;
      int skippedCount = 0;

      // Process rows (skip header row)
      for (int i = 1; i < sheet.maxRows; i++) {
        try {
          final row = sheet.rows[i];
          
          // Skip empty rows
          if (row.isEmpty || row.every((cell) => cell?.value == null)) {
            continue;
          }

          // Parse row data
          final transaction = _parseRowToTransaction(row, userId);
          if (transaction != null) {
            await _databaseHelper.insertTransaction(transaction);
            importedCount++;
            
            if (kDebugMode) {
              print('Imported: ${transaction.description} - ${transaction.amount}');
            }
          } else {
            skippedCount++;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing row $i: $e');
          }
          skippedCount++;
        }
      }

      // Mark as imported
      await markDataAsImported();

      if (kDebugMode) {
        print('Excel import completed: $importedCount imported, $skippedCount skipped');
      }

      return importedCount > 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error importing Excel file: $e');
      }
      return false;
    }
  }

  /// Parse Excel row to Transaction object
  Transaction? _parseRowToTransaction(List<Data?> row, String userId) {
    try {
      // Expected columns: Date, Description, Amount, Category, Type (optional)
      if (row.length < 4) return null;

      // Parse date (Column A)
      final dateCell = row[0]?.value;
      DateTime? date;

      if (dateCell != null) {
        if (dateCell.toString().isNotEmpty) {
          date = _parseDate(dateCell.toString());
        }
      }

      if (date == null) return null;

      // Parse description (Column B)
      final description = row[1]?.value?.toString().trim();
      if (description == null || description.isEmpty) return null;

      // Parse amount (Column C)
      final amountCell = row[2]?.value;
      double? amount;

      if (amountCell != null) {
        final amountStr = amountCell.toString();
        amount = double.tryParse(amountStr.replaceAll(',', ''));
      }

      if (amount == null) return null;

      // Parse category (Column D)
      final category = row[3]?.value?.toString().trim() ?? 'Other';

      // Parse type (Column E) or determine from amount
      TransactionType type;
      if (row.length > 4 && row[4]?.value != null) {
        final typeStr = row[4]!.value.toString().toLowerCase().trim();
        type = typeStr == 'income' ? TransactionType.income : TransactionType.expense;
      } else {
        // Determine type from amount sign
        type = amount >= 0 ? TransactionType.income : TransactionType.expense;
        amount = amount.abs(); // Store as positive value
      }

      // Validate category
      final validCategory = _validateCategory(category, type);

      return Transaction(
        userId: userId,
        description: description,
        amount: amount,
        type: type,
        category: validCategory,
        date: date,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing row: $e');
      }
      return null;
    }
  }

  /// Parse date string to DateTime
  DateTime? _parseDate(String dateStr) {
    try {
      // Try different date formats
      final formats = [
        RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'), // YYYY-MM-DD
        RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})'), // DD/MM/YYYY
        RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})'), // DD-MM-YYYY
      ];

      for (final format in formats) {
        final match = format.firstMatch(dateStr);
        if (match != null) {
          if (format == formats[0]) {
            // YYYY-MM-DD
            return DateTime(
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
            );
          } else {
            // DD/MM/YYYY or DD-MM-YYYY
            return DateTime(
              int.parse(match.group(3)!),
              int.parse(match.group(2)!),
              int.parse(match.group(1)!),
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing date: $dateStr - $e');
      }
    }
    return null;
  }

  /// Validate and map category to predefined categories
  String _validateCategory(String category, TransactionType type) {
    final categoryLower = category.toLowerCase();

    if (type == TransactionType.income) {
      const incomeCategories = ['salary', 'per diem', 'bonus', 'advance', 'other'];
      for (final cat in incomeCategories) {
        if (categoryLower.contains(cat)) {
          return cat.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
        }
      }
      return 'Other';
    } else {
      const expenseCategories = ['food', 'groceries', 'purchase', 'travel', 'entertainment', 'other'];
      for (final cat in expenseCategories) {
        if (categoryLower.contains(cat)) {
          return cat[0].toUpperCase() + cat.substring(1);
        }
      }
      return 'Other';
    }
  }

  /// Reset import status (for testing purposes)
  Future<void> resetImportStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_importedKey);
  }
}
