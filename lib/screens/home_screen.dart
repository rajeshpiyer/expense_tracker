import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/expense_limit_service.dart';
import '../services/notification_service.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../models/currency.dart';
import '../models/transaction.dart' as app_models;
import '../widgets/gradient_header.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _searchController = TextEditingController();

  User? _currentUser;
  double _balance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  Map<String, List<app_models.Transaction>> _groupedTransactions = {};
  Map<String, List<app_models.Transaction>> _filteredGroupedTransactions = {};
  final Map<String, bool> _expandedMonths = {};
  bool _isLoading = true;
  String _searchQuery = '';
  app_models.TransactionType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredGroupedTransactions = {};

    _groupedTransactions.forEach((monthKey, transactions) {
      List<app_models.Transaction> filteredTransactions = transactions.where((transaction) {
        // Search filter
        bool matchesSearch = _searchQuery.isEmpty ||
            transaction.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (transaction.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

        // Type filter
        bool matchesType = _filterType == null || transaction.type == _filterType;

        return matchesSearch && matchesType;
      }).toList();

      if (filteredTransactions.isNotEmpty) {
        _filteredGroupedTransactions[monthKey] = filteredTransactions;
      }
    });
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

      // Apply current filters
      _applyFilters();
    }
  }

  Future<void> _deleteTransaction(int transactionId) async {
    try {
      await _databaseHelper.deleteTransaction(transactionId);
      await _loadData(); // Reload all data after deletion
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _enableNotifications() async {
    try {
      await NotificationService().scheduleDailyFoodReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily food reminders enabled! You\'ll receive notifications at 10 AM, 2 PM, and 9 PM.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enabling notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _disableNotifications() async {
    try {
      await NotificationService().cancelAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily food reminders disabled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disabling notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Food Expense Reminders'),
        content: const Text(
          'Enable daily notifications to remind you to record your food expenses at:\n\n'
          '• 10:00 AM (Breakfast)\n'
          '• 2:00 PM (Lunch)\n'
          '• 9:00 PM (Dinner)',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _disableNotifications();
            },
            child: const Text('Disable'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _enableNotifications();
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showExpenseLimitSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer<ExpenseLimitService>(
        builder: (context, limitService, child) => AlertDialog(
          title: const Text('Monthly Expense Limit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Set a monthly spending limit to track your expenses:'),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enable Expense Limit'),
                value: limitService.isEnabled,
                onChanged: (value) {
                  limitService.setEnabled(value);
                },
                activeColor: const Color(0xFFFFD700),
              ),
              if (limitService.isEnabled) ...[
                const SizedBox(height: 16),
                const Text('Select Monthly Limit:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ExpenseLimitService.limitOptions.map((limit) {
                    final isSelected = limitService.monthlyLimit == limit;
                    return FilterChip(
                      label: Text(limitService.formatLimit(limit)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          limitService.setLimit(limit);
                        }
                      },
                      selectedColor: const Color(0xFFFFD700),
                      checkmarkColor: Colors.black,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
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
              } else if (value == 'notifications') {
                _showNotificationSettings();
              } else if (value == 'expense_limit') {
                _showExpenseLimitSettings();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Color(0xFFFFD700)),
                    SizedBox(width: 8),
                    Text('Food Reminders'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'expense_limit',
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: Color(0xFFFFD700)),
                    SizedBox(width: 8),
                    Text('Expense Limit'),
                  ],
                ),
              ),
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
                    const SizedBox(height: 16),

                    // Expense Limit Chart
                    Consumer<ExpenseLimitService>(
                      builder: (context, limitService, child) {
                        if (!limitService.isEnabled) {
                          return const SizedBox.shrink();
                        }

                        final progress = limitService.calculateProgress(_totalExpense);
                        final statusMessage = limitService.getStatusMessage(_totalExpense);
                        final isOverLimit = limitService.isOverLimit(_totalExpense);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      color: isOverLimit ? Colors.red : const Color(0xFFFFD700),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Monthly Expense Limit',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Progress Bar
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.grey[800],
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: isOverLimit
                                            ? Colors.red
                                            : progress > 0.8
                                                ? Colors.orange
                                                : const Color(0xFFFFD700),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Consumer<CurrencyService>(
                                      builder: (context, currencyService, child) {
                                        return Text(
                                          '${currencyService.formatAmount(_totalExpense)} / ${currencyService.formatAmount(limitService.monthlyLimit)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                    ),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isOverLimit ? Colors.red : Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  statusMessage,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOverLimit
                                        ? Colors.red
                                        : progress > 0.8
                                            ? Colors.orange
                                            : Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
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

                    // Search and Filter Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Search Bar
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by category or description...',
                                prefixIcon: const Icon(Icons.search, color: Color(0xFFFFD700)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFFFD700)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Filter Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: FilterChip(
                                    label: const Text('All'),
                                    selected: _filterType == null,
                                    onSelected: (selected) {
                                      setState(() {
                                        _filterType = null;
                                        _applyFilters();
                                      });
                                    },
                                    selectedColor: const Color(0xFFFFD700),
                                    checkmarkColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilterChip(
                                    label: const Text('Income'),
                                    selected: _filterType == app_models.TransactionType.income,
                                    onSelected: (selected) {
                                      setState(() {
                                        _filterType = selected ? app_models.TransactionType.income : null;
                                        _applyFilters();
                                      });
                                    },
                                    selectedColor: Colors.green,
                                    checkmarkColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilterChip(
                                    label: const Text('Expense'),
                                    selected: _filterType == app_models.TransactionType.expense,
                                    onSelected: (selected) {
                                      setState(() {
                                        _filterType = selected ? app_models.TransactionType.expense : null;
                                        _applyFilters();
                                      });
                                    },
                                    selectedColor: Colors.red,
                                    checkmarkColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monthly Grouped Transactions
                    _filteredGroupedTransactions.isEmpty
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
                                children: _filteredGroupedTransactions.entries.map((entry) {
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
                                                      onDelete: () => _deleteTransaction(transaction.id!),
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
  final VoidCallback? onDelete;

  const _TransactionItem({
    required this.transaction,
    required this.currencyService,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == app_models.TransactionType.income;
    final color = isIncome ? Colors.green : Colors.red;
    final icon = isIncome ? Icons.add : Icons.remove;

    return Dismissible(
      key: Key('transaction_${transaction.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text('Are you sure you want to delete this transaction?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        onDelete?.call();
      },
      child: Card(
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
      ),
    );
  }
}
