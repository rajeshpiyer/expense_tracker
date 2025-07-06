import 'dart:io';
import 'package:excel/excel.dart';

void main() async {
  try {
    // Read the AD Expenses.xlsx file
    var file = File('assets/data/AD Expenses.xlsx');
    var bytes = file.readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    
    print('=== ANALYZING AD EXPENSES.xlsx ===\n');
    
    // Get all sheet names
    print('Available sheets:');
    for (var table in excel.tables.keys) {
      print('- $table');
    }
    print('');
    
    // Analyze the first sheet (or main sheet)
    var sheetName = excel.tables.keys.first;
    var sheet = excel.tables[sheetName];
    
    if (sheet == null) {
      print('No data found in sheet: $sheetName');
      return;
    }
    
    print('Analyzing sheet: $sheetName');
    print('Total rows: ${sheet.maxRows}');
    print('Total columns: ${sheet.maxColumns}');
    print('');
    
    // Analyze headers (first row)
    print('=== HEADERS (Row 1) ===');
    if (sheet.maxRows > 0) {
      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        var value = cell?.value?.toString() ?? 'Empty';
        print('Column ${String.fromCharCode(65 + col)}: $value');
      }
    }
    print('');
    
    // Show first 10 rows of data
    print('=== SAMPLE DATA (First 10 rows) ===');
    for (int row = 0; row < (sheet.maxRows < 11 ? sheet.maxRows : 11); row++) {
      print('Row ${row + 1}:');
      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        var value = cell?.value?.toString() ?? 'Empty';
        print('  ${String.fromCharCode(65 + col)}: $value');
      }
      print('');
    }
    
    // Analyze data patterns
    print('=== DATA ANALYSIS ===');
    
    // Look for date patterns
    print('Looking for date patterns...');
    for (int row = 1; row < (sheet.maxRows < 6 ? sheet.maxRows : 6); row++) {
      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        var value = cell?.value?.toString() ?? '';
        
        // Check if it looks like a date
        if (value.contains('/') || value.contains('-') || value.contains('.')) {
          print('  Potential date in ${String.fromCharCode(65 + col)}$row: $value');
        }
      }
    }
    print('');
    
    // Look for amount patterns
    print('Looking for amount patterns...');
    for (int row = 1; row < (sheet.maxRows < 6 ? sheet.maxRows : 6); row++) {
      for (int col = 0; col < sheet.maxColumns; col++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        var value = cell?.value?.toString() ?? '';
        
        // Check if it looks like an amount
        if (RegExp(r'^\-?\d+\.?\d*$').hasMatch(value.trim()) || 
            value.contains('\$') || value.contains('AED') || value.contains('USD')) {
          print('  Potential amount in ${String.fromCharCode(65 + col)}$row: $value');
        }
      }
    }
    print('');
    
    print('=== ANALYSIS COMPLETE ===');
    print('Please review the structure above to help with conversion mapping.');
    
  } catch (e) {
    print('Error analyzing Excel file: $e');
  }
}
