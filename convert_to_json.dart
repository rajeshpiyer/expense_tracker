import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';

void main() async {
  print('🔄 CONVERTING AD EXPENSES TO JSON FORMAT\n');
  
  try {
    // Read the original file
    var inputFile = File('assets/data/AD Expenses.xlsx');
    var bytes = inputFile.readAsBytesSync();
    var inputExcel = Excel.decodeBytes(bytes);
    
    // Get the first sheet
    var inputSheet = inputExcel.tables[inputExcel.tables.keys.first];
    if (inputSheet == null) {
      print('Error: No data found in input file');
      return;
    }
    
    print('📊 Converting data to JSON...');
    
    List<Map<String, dynamic>> transactions = [];
    int processedCount = 0;
    int skippedCount = 0;
    
    // Process each row from the input file (skip header row)
    for (int inputRowIndex = 1; inputRowIndex < inputSheet.maxRows; inputRowIndex++) {
      try {
        // Get data from input row
        var dateCell = inputSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: inputRowIndex)); // Column B
        var particularsCell = inputSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: inputRowIndex)); // Column C
        var incomeCell = inputSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: inputRowIndex)); // Column D
        var expenditureCell = inputSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: inputRowIndex)); // Column E
        
        var dateStr = dateCell?.value?.toString().trim() ?? '';
        var description = particularsCell?.value?.toString().trim() ?? '';
        var incomeStr = incomeCell?.value?.toString().trim() ?? '';
        var expenditureStr = expenditureCell?.value?.toString().trim() ?? '';
        
        // Skip empty rows
        if (dateStr.isEmpty || description.isEmpty) {
          skippedCount++;
          continue;
        }
        
        // Convert date from DD-MM-YYYY to YYYY-MM-DD
        String convertedDate = '';
        if (dateStr.contains('-')) {
          var parts = dateStr.split('-');
          if (parts.length == 3) {
            var day = parts[0].padLeft(2, '0');
            var month = parts[1].padLeft(2, '0');
            var year = parts[2];
            
            // Fix year if it's 2025 (should probably be 2024)
            if (year == '2025') {
              year = '2024';
            }
            
            convertedDate = '$year-$month-$day';
          }
        }
        
        if (convertedDate.isEmpty) {
          print('Skipping row ${inputRowIndex + 1}: Invalid date format: $dateStr');
          skippedCount++;
          continue;
        }
        
        // Determine amount and type
        double amount = 0;
        String type = '';
        String category = '';
        
        if (incomeStr.isNotEmpty && incomeStr != 'Empty') {
          // This is income
          var parsed = double.tryParse(incomeStr);
          if (parsed != null && parsed > 0) {
            amount = parsed;
            type = 'income';
            category = _categorizeIncome(description);
          }
        } else if (expenditureStr.isNotEmpty && expenditureStr != 'Empty') {
          // This is expense
          var parsed = double.tryParse(expenditureStr);
          if (parsed != null && parsed > 0) {
            amount = -parsed; // Make negative for expenses
            type = 'expense';
            category = _categorizeExpense(description);
          }
        }
        
        if (amount == 0) {
          print('Skipping row ${inputRowIndex + 1}: No valid amount found');
          skippedCount++;
          continue;
        }
        
        // Add to transactions list
        transactions.add({
          'date': convertedDate,
          'description': description,
          'amount': amount,
          'category': category,
          'type': type,
        });
        
        processedCount++;
        
        if (processedCount <= 10) {
          print('Transaction ${processedCount}: $convertedDate | $description | $amount | $category | $type');
        }
        
      } catch (e) {
        print('Error processing row ${inputRowIndex + 1}: $e');
        skippedCount++;
      }
    }
    
    // Create JSON structure
    Map<String, dynamic> jsonData = {
      'metadata': {
        'version': '1.0',
        'created': DateTime.now().toIso8601String(),
        'source': 'AD Expenses.xlsx',
        'total_transactions': processedCount,
        'target_user': 'prajeshiyer@gmail.com',
        'description': 'Initial expense data for automatic import'
      },
      'transactions': transactions
    };
    
    // Save as JSON file
    String jsonString = JsonEncoder.withIndent('  ').convert(jsonData);
    File('assets/data/initial_expenses.json').writeAsStringSync(jsonString);
    
    print('\n✅ CONVERSION COMPLETED!');
    print('📊 SUMMARY:');
    print('- Processed transactions: $processedCount');
    print('- Skipped rows: $skippedCount');
    print('- Output file: assets/data/initial_expenses.json');
    print('\n🎯 Ready for import into expense tracker app!');
    
  } catch (e) {
    print('❌ Error during conversion: $e');
  }
}

String _categorizeIncome(String description) {
  var desc = description.toLowerCase();
  
  if (desc.contains('per diem') || desc.contains('perdiem')) {
    return 'Per Diem';
  } else if (desc.contains('salary') || desc.contains('wage')) {
    return 'Salary';
  } else if (desc.contains('bonus') || desc.contains('incentive')) {
    return 'Bonus';
  } else if (desc.contains('advance') || desc.contains('prepaid')) {
    return 'Advance';
  } else {
    return 'Other';
  }
}

String _categorizeExpense(String description) {
  var desc = description.toLowerCase();
  
  if (desc.contains('breakfast') || desc.contains('lunch') || desc.contains('dinner') || 
      desc.contains('food') || desc.contains('meal') || desc.contains('coffee') || 
      desc.contains('tea') || desc.contains('restaurant')) {
    return 'Food';
  } else if (desc.contains('grocery') || desc.contains('groceries') || desc.contains('supermarket')) {
    return 'Groceries';
  } else if (desc.contains('taxi') || desc.contains('bus') || desc.contains('transport') || 
             desc.contains('flight') || desc.contains('airport') || desc.contains('travel')) {
    return 'Travel';
  } else if (desc.contains('movie') || desc.contains('entertainment') || desc.contains('game') || 
             desc.contains('cinema') || desc.contains('show')) {
    return 'Entertainment';
  } else if (desc.contains('oil') || desc.contains('soap') || desc.contains('shampoo') || 
             desc.contains('toothpaste') || desc.contains('laundry') || desc.contains('detergent') ||
             desc.contains('tide') || desc.contains('bag') || desc.contains('clothes')) {
    return 'Purchase';
  } else {
    return 'Other';
  }
}
