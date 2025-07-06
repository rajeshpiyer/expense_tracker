import 'dart:io';
import 'package:excel/excel.dart';

void main() async {
  try {
    print('=== CONVERTING AD EXPENSES TO PROPER FORMAT ===\n');
    
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
    
    // Create new Excel file with proper format
    var outputExcel = Excel.createExcel();
    var outputSheet = outputExcel['Sheet1'];
    
    // Add headers for the new format
    outputSheet.cell(CellIndex.indexByString("A1")).value = TextCellValue('Date');
    outputSheet.cell(CellIndex.indexByString("B1")).value = TextCellValue('Description');
    outputSheet.cell(CellIndex.indexByString("C1")).value = TextCellValue('Amount');
    outputSheet.cell(CellIndex.indexByString("D1")).value = TextCellValue('Category');
    outputSheet.cell(CellIndex.indexByString("E1")).value = TextCellValue('Type');
    
    int outputRow = 2; // Start from row 2 (after headers)
    int convertedCount = 0;
    int skippedCount = 0;
    
    print('Converting data...\n');
    
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
        String amount = '';
        String type = '';
        String category = '';
        
        if (incomeStr.isNotEmpty && incomeStr != 'Empty') {
          // This is income
          amount = incomeStr;
          type = 'income';
          category = _categorizeIncome(description);
        } else if (expenditureStr.isNotEmpty && expenditureStr != 'Empty') {
          // This is expense
          amount = '-$expenditureStr'; // Make negative for expenses
          type = 'expense';
          category = _categorizeExpense(description);
        } else {
          print('Skipping row ${inputRowIndex + 1}: No amount found');
          skippedCount++;
          continue;
        }
        
        // Add to output sheet
        outputSheet.cell(CellIndex.indexByString("A$outputRow")).value = TextCellValue(convertedDate);
        outputSheet.cell(CellIndex.indexByString("B$outputRow")).value = TextCellValue(description);
        outputSheet.cell(CellIndex.indexByString("C$outputRow")).value = TextCellValue(amount);
        outputSheet.cell(CellIndex.indexByString("D$outputRow")).value = TextCellValue(category);
        outputSheet.cell(CellIndex.indexByString("E$outputRow")).value = TextCellValue(type);
        
        convertedCount++;
        outputRow++;
        
        // Print progress every 50 rows
        if (convertedCount % 50 == 0) {
          print('Converted $convertedCount rows...');
        }
        
      } catch (e) {
        print('Error processing row ${inputRowIndex + 1}: $e');
        skippedCount++;
      }
    }
    
    // Save the converted file
    var outputBytes = outputExcel.save();
    if (outputBytes != null) {
      File('assets/data/expenses.xlsx')
        ..createSync(recursive: true)
        ..writeAsBytesSync(outputBytes);
      
      print('\n=== CONVERSION COMPLETE ===');
      print('✅ Successfully converted $convertedCount transactions');
      print('⚠️  Skipped $skippedCount rows (empty or invalid data)');
      print('📁 Output saved as: assets/data/expenses.xlsx');
      print('🎯 Ready for import into your expense tracker app!');
      
      // Show sample of converted data
      print('\n=== SAMPLE CONVERTED DATA ===');
      print('Date       | Description              | Amount    | Category     | Type');
      print('-----------|--------------------------|-----------|--------------|--------');
      
      var sampleSheet = outputExcel['Sheet1'];
      for (int i = 2; i <= (convertedCount < 8 ? convertedCount + 1 : 9); i++) {
        var date = sampleSheet?.cell(CellIndex.indexByString("A$i"))?.value?.toString() ?? '';
        var desc = sampleSheet?.cell(CellIndex.indexByString("B$i"))?.value?.toString() ?? '';
        var amt = sampleSheet?.cell(CellIndex.indexByString("C$i"))?.value?.toString() ?? '';
        var cat = sampleSheet?.cell(CellIndex.indexByString("D$i"))?.value?.toString() ?? '';
        var typ = sampleSheet?.cell(CellIndex.indexByString("E$i"))?.value?.toString() ?? '';
        
        // Truncate description if too long
        if (desc.length > 24) desc = desc.substring(0, 21) + '...';
        
        print('${date.padRight(10)} | ${desc.padRight(24)} | ${amt.padRight(9)} | ${cat.padRight(12)} | $typ');
      }
      
    } else {
      print('❌ Error: Failed to save converted file');
    }
    
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
