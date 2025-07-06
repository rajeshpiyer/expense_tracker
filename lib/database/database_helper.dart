import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/transaction.dart' as app_models;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'expense_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        photoUrl TEXT,
        createdAt INTEGER NOT NULL,
        lastLoginAt INTEGER NOT NULL
      )
    ''');

    // Create Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX idx_transactions_userId ON transactions(userId)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_date ON transactions(date)
    ''');

    await db.execute('''
      CREATE INDEX idx_transactions_type ON transactions(type)
    ''');
  }

  // User operations
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getUser(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Transaction operations
  Future<int> insertTransaction(app_models.Transaction transaction) async {
    final db = await database;
    return await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<app_models.Transaction>> getTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return app_models.Transaction.fromMap(maps[i]);
    });
  }

  Future<List<app_models.Transaction>> getTransactionsByType(
      String userId, app_models.TransactionType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ? AND type = ?',
      whereArgs: [userId, type.name],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return app_models.Transaction.fromMap(maps[i]);
    });
  }

  Future<List<app_models.Transaction>> getTransactionsByMonth(
      String userId, String monthKey) async {
    final db = await database;

    // Parse the month key (format: yyyy-MM)
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // Calculate start and end timestamps for the month
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ? AND date >= ? AND date <= ?',
      whereArgs: [
        userId,
        startOfMonth.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch
      ],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return app_models.Transaction.fromMap(maps[i]);
    });
  }

  Future<List<app_models.Transaction>> getTransactionsByDateRange(
      String userId, DateTime startDate, DateTime endDate) async {
    final db = await database;

    // Convert dates to milliseconds for comparison
    final startMillis = startDate.millisecondsSinceEpoch;
    final endMillis = endDate.millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'userId = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startMillis, endMillis],
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return app_models.Transaction.fromMap(maps[i]);
    });
  }

  Future<double> getTotalAmount(String userId, app_models.TransactionType type) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE userId = ? AND type = ?',
      [userId, type.name],
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<double> getCurrentMonthAmount(String userId, app_models.TransactionType type) async {
    final db = await database;

    // Get current month start and end
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM transactions WHERE userId = ? AND type = ? AND date >= ? AND date <= ?',
      [
        userId,
        type.name,
        startOfMonth.millisecondsSinceEpoch,
        endOfMonth.millisecondsSinceEpoch
      ],
    );

    return (result.first['total'] as double?) ?? 0.0;
  }

  Future<double> getBalance(String userId) async {
    final totalIncome = await getTotalAmount(userId, app_models.TransactionType.income);
    final totalExpense = await getTotalAmount(userId, app_models.TransactionType.expense);
    // Since expenses are stored as negative amounts, we add them directly
    // Balance = Income + Expenses (where expenses are negative)
    return totalIncome + totalExpense;
  }

  Future<int> updateTransaction(app_models.Transaction transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Utility methods
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'expense_tracker.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
