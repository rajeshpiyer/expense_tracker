import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/currency.dart';
import '../models/transaction.dart' as app_models;
import '../widgets/gradient_header.dart';
import 'login_screen.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  User? _currentUser;
  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  Map<String, List<app_models.Transaction>> _groupedTransactions = {};
  final Map<String, bool> _expandedMonths = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    _currentUser = _authService.currentUser;
    
    if (_currentUser != null) {
      await _loadFinancialData();
      await _loadGroupedTransactions();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadFinancialData() async {
    if (_currentUser != null) {
      _balance = await _databaseHelper.getBalance(_currentUser!.id);
      _totalIncome = await _databaseHelper.getTotalAmount(_currentUser!.id, app_models.TransactionType.income);
      _totalExpense = await _databaseHelper.getTotalAmount(_currentUser!.id, app_models.TransactionType.expense);
    }
  }

  Future<void> _loadGroupedTransactions() async {
    if (_currentUser != null) {
      final transactions = await _databaseHelper.getTransactions(_currentUser!.id);

      // Group transactions by month
      _groupedTransactions.clear();
      _expandedMonths.clear();

      final now = DateTime.now();
      final currentMonthKey = DateFormat('yyyy-MM').format(now);

      for (final transaction in transactions) {
        final monthKey = DateFormat('yyyy-MM').format(transaction.date);
        if (!_groupedTransactions.containsKey(monthKey)) {
          _groupedTransactions[monthKey] = [];
          // Only expand current month by default
          _expandedMonths[monthKey] = monthKey == currentMonthKey;
        }
        _groupedTransactions[monthKey]!.add(transaction);
      }

      // Sort months in descending order (newest first)
      final sortedKeys = _groupedTransactions.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      final sortedGrouped = <String, List<app_models.Transaction>>{};
      for (final key in sortedKeys) {
        sortedGrouped[key] = _groupedTransactions[key]!;
      }
      _groupedTransactions = sortedGrouped;
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _navigateToAddTransaction() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
    );
    
    if (result == true) {
      // Refresh data if a transaction was added
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: GradientHeader(
        title: 'Expense Tracker',
        actions: [
          // Currency Dropdown
          Consumer<CurrencyService>(
            builder: (context, currencyService, child) {
              return PopupMenuButton<Currency>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currencyService.selectedCurrency.code,
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFFFFD700)),
                  ],
                ),
                onSelected: (Currency currency) {
                  currencyService.setCurrency(currency);
                },
                itemBuilder: (BuildContext context) => Currency.values
                    .map((currency) => PopupMenuItem<Currency>(
                          value: currency,
                          child: Row(
                            children: [
                              Text(currency.symbol),
                              const SizedBox(width: 8),
                              Text('${currency.code} - ${currency.name}'),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          // Menu
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Greeting
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: _currentUser!.photoUrl != null
                                  ? NetworkImage(_currentUser!.photoUrl!)
                                  : null,
                              child: _currentUser!.photoUrl == null
                                  ? Text(
                                      _currentUser!.name.isNotEmpty
                                          ? _currentUser!.name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(fontSize: 24),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hi, ${_currentUser!.name}!',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Welcome back to your expense tracker',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Financial Summary
                    Consumer<CurrencyService>(
                      builder: (context, currencyService, child) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    title: 'Balance',
                                    amount: _balance,
                                    color: _balance >= 0 ? Colors.green : Colors.red,
                                    icon: Icons.account_balance_wallet,
                                    currencyService: currencyService,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    title: 'Income',
                                    amount: _totalIncome,
                                    color: Colors.green,
                                    icon: Icons.trending_up,
                                    currencyService: currencyService,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SummaryCard(
                                    title: 'Expenses',
                                    amount: _totalExpense,
                                    color: Colors.red,
                                    icon: Icons.trending_down,
                                    currencyService: currencyService,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Transactions by Month
                    const Text(
                      'Transactions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monthly Grouped Transactions
                    _groupedTransactions.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No transactions yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to add your first transaction',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Consumer<CurrencyService>(
                            builder: (context, currencyService, child) {
                              return Column(
                                children: _groupedTransactions.entries.map((entry) {
                                  final monthKey = entry.key;
                                  final transactions = entry.value;
                                  final isExpanded = _expandedMonths[monthKey] ?? false;
                                  final monthDate = DateTime.parse('$monthKey-01');
                                  final monthName = DateFormat('MMMM yyyy').format(monthDate);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          title: Text(
                                            monthName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${transactions.length} transaction${transactions.length != 1 ? 's' : ''}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                          trailing: Icon(
                                            isExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: const Color(0xFFFFD700),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _expandedMonths[monthKey] = !isExpanded;
                                            });
                                          },
                                        ),
                                        if (isExpanded)
                                          Column(
                                            children: transactions
                                                .map((transaction) => _TransactionItem(
                                                      transaction: transaction,
                                                      currencyService: currencyService,
                                                    ))
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddTransaction,
        backgroundColor: const Color(0xFFFFD700),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final CurrencyService currencyService;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    required this.currencyService,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: title == 'Balance' ? Colors.grey[400] : color,
                  size: 20
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currencyService.formatAmount(amount),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final app_models.Transaction transaction;
  final CurrencyService currencyService;

  const _TransactionItem({
    required this.transaction,
    required this.currencyService,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == app_models.TransactionType.income;
    final color = isIncome ? Colors.green : Colors.red;
    final icon = isIncome ? Icons.add : Icons.remove;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(transaction.category),
        subtitle: transaction.description != null
            ? Text(transaction.description!)
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'}${currencyService.formatAmount(transaction.amount)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              DateFormat('MMM dd').format(transaction.date),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
