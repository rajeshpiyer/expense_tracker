import 'dart:io';
import 'package:excel/excel.dart';

void main() async {
  // Create a new Excel document
  var excel = Excel.createExcel();
  
  // Get the default sheet
  Sheet sheetObject = excel['Sheet1'];
  
  // Add headers
  sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue('Date');
  sheetObject.cell(CellIndex.indexByString("B1")).value = TextCellValue('Description');
  sheetObject.cell(CellIndex.indexByString("C1")).value = TextCellValue('Amount');
  sheetObject.cell(CellIndex.indexByString("D1")).value = TextCellValue('Category');
  sheetObject.cell(CellIndex.indexByString("E1")).value = TextCellValue('Type');
  
  // Sample data
  final data = [
    ['2024-06-14', 'Morning Coffee', '-5.50', 'Food', 'expense'],
    ['2024-06-14', 'Lunch at Restaurant', '-25.00', 'Food', 'expense'],
    ['2024-06-15', 'Monthly Salary', '5000.00', 'Salary', 'income'],
    ['2024-06-15', 'Grocery Shopping', '-120.75', 'Groceries', 'expense'],
    ['2024-06-16', 'Bus Ticket', '-3.00', 'Travel', 'expense'],
    ['2024-06-16', 'Movie Tickets', '-30.00', 'Entertainment', 'expense'],
    ['2024-06-17', 'Breakfast', '-8.50', 'Food', 'expense'],
    ['2024-06-17', 'Office Supplies', '-45.00', 'Purchase', 'expense'],
    ['2024-06-18', 'Dinner with Friends', '-65.00', 'Food', 'expense'],
    ['2024-06-19', 'Weekly Groceries', '-95.50', 'Groceries', 'expense'],
    ['2024-06-20', 'Taxi Ride', '-15.00', 'Travel', 'expense'],
    ['2024-06-20', 'Per Diem Allowance', '50.00', 'Per Diem', 'income'],
    ['2024-06-21', 'Coffee Shop', '-6.75', 'Food', 'expense'],
    ['2024-06-21', 'Book Purchase', '-25.00', 'Purchase', 'expense'],
    ['2024-06-22', 'Weekend Groceries', '-85.25', 'Groceries', 'expense'],
    ['2024-06-23', 'Lunch', '-12.00', 'Food', 'expense'],
    ['2024-06-24', 'Bonus Payment', '500.00', 'Bonus', 'income'],
    ['2024-06-24', 'Gas Station', '-40.00', 'Travel', 'expense'],
    ['2024-06-25', 'Dinner', '-22.50', 'Food', 'expense'],
    ['2024-06-26', 'Pharmacy', '-18.75', 'Purchase', 'expense'],
    ['2024-06-27', 'Coffee', '-4.50', 'Food', 'expense'],
    ['2024-06-28', 'Monthly Groceries', '-150.00', 'Groceries', 'expense'],
    ['2024-06-29', 'Concert Tickets', '-80.00', 'Entertainment', 'expense'],
    ['2024-06-30', 'Advance Payment', '200.00', 'Advance', 'income'],
  ];
  
  // Add data rows
  for (int i = 0; i < data.length; i++) {
    final row = data[i];
    final rowIndex = i + 2; // Start from row 2 (after header)
    
    sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = TextCellValue(row[0]);
    sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = TextCellValue(row[1]);
    sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = TextCellValue(row[2]);
    sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = TextCellValue(row[3]);
    sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = TextCellValue(row[4]);
  }
  
  // Save the file
  var fileBytes = excel.save();
  if (fileBytes != null) {
    File('assets/data/expenses.xlsx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    print('Excel file created successfully at assets/data/expenses.xlsx');
  }
}
