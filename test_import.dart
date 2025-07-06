import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'lib/services/excel_import_service.dart';
import 'lib/services/database_service.dart';

void main() async {
  print('🧪 TESTING EXCEL IMPORT FUNCTIONALITY\n');
  
  try {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Initialize database service
    final dbService = DatabaseService();
    await dbService.initDatabase();
    
    print('✅ Database initialized successfully');
    
    // Test Excel import service
    final importService = ExcelImportService();
    
    print('📊 Testing Excel import for user: prajeshiyer@gmail.com');
    
    // Simulate the import process
    await importService.importExpensesForUser('prajeshiyer@gmail.com');
    
    print('✅ Import process completed');
    
    // Check if transactions were imported
    final transactions = await dbService.getTransactions();
    
    print('\n📈 IMPORT RESULTS:');
    print('Total transactions imported: ${transactions.length}');
    
    if (transactions.isNotEmpty) {
      print('\n📋 SAMPLE IMPORTED TRANSACTIONS:');
      print('Date       | Description              | Amount    | Category     | Type');
      print('-----------|--------------------------|-----------|--------------|--------');
      
      for (int i = 0; i < (transactions.length < 10 ? transactions.length : 10); i++) {
        final t = transactions[i];
        var desc = t.description;
        if (desc.length > 24) desc = desc.substring(0, 21) + '...';
        
        print('${t.date.toString().substring(0, 10).padRight(10)} | ${desc.padRight(24)} | ${t.amount.toString().padRight(9)} | ${t.category.padRight(12)} | ${t.type}');
      }
      
      // Calculate totals
      double totalIncome = 0;
      double totalExpenses = 0;
      
      for (var t in transactions) {
        if (t.type == 'income') {
          totalIncome += t.amount;
        } else {
          totalExpenses += t.amount.abs();
        }
      }
      
      print('\n💰 FINANCIAL SUMMARY:');
      print('Total Income: AED ${totalIncome.toStringAsFixed(2)}');
      print('Total Expenses: AED ${totalExpenses.toStringAsFixed(2)}');
      print('Net Balance: AED ${(totalIncome - totalExpenses).toStringAsFixed(2)}');
      
      print('\n🎯 SUCCESS: Excel import completed successfully!');
      print('Your AD Expenses data has been imported into the expense tracker.');
      
    } else {
      print('⚠️  No transactions found. Import may have failed or file is empty.');
    }
    
  } catch (e) {
    print('❌ Error during import test: $e');
  }
}
