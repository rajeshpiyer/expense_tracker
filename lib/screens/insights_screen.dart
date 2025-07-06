import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart' as app_models;
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/currency_service.dart';
import '../services/expense_limit_service.dart';
import '../database/database_helper.dart';
import '../widgets/gradient_header.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final AuthService _authService = AuthService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  User? _currentUser;
  bool _isLoading = true;
  
  // Daily chart data
  Map<String, double> _dailyIncome = {};
  Map<String, double> _dailyExpenses = {};
  List<String> _days = [];
  
  // Category data
  Map<String, double> _expenseCategories = {};
  Map<String, double> _incomeCategories = {};

  // Monthly data
  Map<String, double> _monthlyIncome = {};
  
  // Scroll controller for daily chart
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _currentUser = _authService.currentUser;
      if (_currentUser != null) {
        await _loadChartData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChartData() async {
    if (_currentUser == null) return;

    // Get all transactions
    final allTransactions = await _databaseHelper.getTransactions(_currentUser!.id);
    
    // Generate daily data for the last 90 days
    final now = DateTime.now();
    _days = [];
    _dailyIncome = {};
    _dailyExpenses = {};
    _expenseCategories = {};
    _incomeCategories = {};

    // Generate last 90 days
    for (int i = 89; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateFormat('yyyy-MM-dd').format(date);
      _days.add(dayKey);
      _dailyIncome[dayKey] = 0.0;
      _dailyExpenses[dayKey] = 0.0;
    }

    // Initialize monthly income data for last 12 months
    _monthlyIncome.clear();
    for (int i = 11; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(monthDate);
      _monthlyIncome[monthKey] = 0.0;
    }

    // Process transactions
    for (final transaction in allTransactions) {
      final dayKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      final monthKey = DateFormat('yyyy-MM').format(transaction.date);

      if (transaction.type == app_models.TransactionType.income) {
        // Daily income
        if (_dailyIncome.containsKey(dayKey)) {
          _dailyIncome[dayKey] = (_dailyIncome[dayKey] ?? 0.0) + transaction.amount;
        }
        // Monthly income
        if (_monthlyIncome.containsKey(monthKey)) {
          _monthlyIncome[monthKey] = (_monthlyIncome[monthKey] ?? 0.0) + transaction.amount;
        }
        // Income categories (overall)
        _incomeCategories[transaction.category] =
            (_incomeCategories[transaction.category] ?? 0.0) + transaction.amount;
      } else {
        // Daily expenses (convert negative to positive for chart)
        if (_dailyExpenses.containsKey(dayKey)) {
          _dailyExpenses[dayKey] = (_dailyExpenses[dayKey] ?? 0.0) + transaction.amount.abs();
        }
        // Expense categories (overall, convert to positive)
        _expenseCategories[transaction.category] =
            (_expenseCategories[transaction.category] ?? 0.0) + transaction.amount.abs();
      }
    }

    // Scroll to the end (most recent data)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }



  List<FlSpot> _getDailyExpenseSpots() {
    final spots = <FlSpot>[];
    
    for (int i = 0; i < _days.length; i++) {
      final dayKey = _days[i];
      final expenses = _dailyExpenses[dayKey] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), expenses));
    }
    
    return spots;
  }

  List<FlSpot> _getDailyLimitSpots(double monthlyLimit) {
    final spots = <FlSpot>[];
    final dailyLimit = monthlyLimit / 30; // Approximate daily limit
    
    for (int i = 0; i < _days.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyLimit));
    }
    
    return spots;
  }

  String _getDayLabel(int index) {
    if (index >= 0 && index < _days.length) {
      final dayKey = _days[index];
      final date = DateTime.parse(dayKey);
      return DateFormat('MMM dd').format(date);
    }
    return '';
  }

  double _getMaxY() {
    double maxExpenses = 0.0;

    for (final expense in _dailyExpenses.values) {
      if (expense > maxExpenses) maxExpenses = expense;
    }

    return maxExpenses > 0 ? maxExpenses * 1.1 : 100; // Add 10% padding
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientHeader(
        title: 'Insights',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? const Center(
                  child: Text(
                    'Please sign in to view insights',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily Line Chart
                        _buildDailyLineChart(),
                        const SizedBox(height: 24),

                        // Monthly Income Bar Chart
                        _buildMonthlyIncomeBarChart(),
                        const SizedBox(height: 24),

                        // Expense Categories Bar Chart
                        _buildExpenseCategoriesChart(),
                        const SizedBox(height: 24),

                        // Income Categories Pie Chart
                        _buildIncomeCategoriesChart(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDailyLineChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Expenses (Last 90 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scroll horizontally to view past data',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendItem(color: Colors.red, label: 'Expenses'),
                Consumer<ExpenseLimitService>(
                  builder: (context, limitService, child) {
                    if (limitService.isEnabled) {
                      return _LegendItem(color: const Color(0xFFFFD700), label: 'Daily Limit');
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Chart
            SizedBox(
              height: 300,
              child: Consumer2<CurrencyService, ExpenseLimitService>(
                builder: (context, currencyService, limitService, child) {
                  final maxY = _getMaxY();
                  if (maxY <= 0) {
                    return const Center(
                      child: Text(
                        'No transaction data available',
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _days.length * 8.0, // 8 pixels per day
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: maxY / 5,
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    currencyService.formatAmount(value),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 7, // Show every 7th day
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index % 7 == 0) {
                                    return Text(
                                      _getDayLabel(index),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: (_days.length - 1).toDouble(),
                          minY: 0,
                          maxY: maxY,
                          lineBarsData: [
                            // Expense line
                            LineChartBarData(
                              spots: _getDailyExpenseSpots(),
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.red.withOpacity(0.1),
                              ),
                            ),
                            // Expense limit line
                            if (limitService.isEnabled)
                              LineChartBarData(
                                spots: _getDailyLimitSpots(limitService.monthlyLimit),
                                isCurved: false,
                                color: const Color(0xFFFFD700),
                                barWidth: 1,
                                dotData: const FlDotData(show: false),
                                dashArray: [5, 5],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCategoriesChart() {
    if (_expenseCategories.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No expense data available',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final sortedCategories = _expenseCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expense Categories (Overall)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: Consumer<CurrencyService>(
                builder: (context, currencyService, child) {
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: sortedCategories.first.value * 1.1,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final category = sortedCategories[group.x.toInt()].key;
                            final amount = sortedCategories[group.x.toInt()].value;
                            return BarTooltipItem(
                              '$category\n${currencyService.formatAmount(amount)}',
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                currencyService.formatAmount(value),
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < sortedCategories.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    sortedCategories[index].key,
                                    style: const TextStyle(fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: sortedCategories.asMap().entries.map((entry) {
                        final index = entry.key;
                        final categoryData = entry.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: categoryData.value,
                              color: Colors.red.withValues(alpha: 0.8),
                              width: 20,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeCategoriesChart() {
    if (_incomeCategories.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No income data available',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    final total = _incomeCategories.values.fold(0.0, (sum, value) => sum + value);
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Income Categories (Overall)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: Consumer<CurrencyService>(
                builder: (context, currencyService, child) {
                  return Row(
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: _incomeCategories.entries.toList().asMap().entries.map((entry) {
                              final index = entry.key;
                              final categoryData = entry.value;
                              final percentage = (categoryData.value / total) * 100;

                              return PieChartSectionData(
                                color: colors[index % colors.length],
                                value: categoryData.value,
                                title: '${percentage.toStringAsFixed(1)}%',
                                radius: 80,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // Legend
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _incomeCategories.entries.toList().asMap().entries.map((entry) {
                            final index = entry.key;
                            final categoryData = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: colors[index % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          categoryData.key,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          currencyService.formatAmount(categoryData.value),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMonthlyIncomeBarChart() {
    if (_monthlyIncome.isEmpty) {
      return const SizedBox.shrink();
    }

    final months = _monthlyIncome.keys.toList()..sort();
    final maxIncome = _monthlyIncome.values.isNotEmpty
        ? _monthlyIncome.values.reduce((a, b) => a > b ? a : b)
        : 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Income (Last 12 Months)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.green, label: 'Income'),
              ],
            ),
            const SizedBox(height: 16),

            // Chart
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxIncome * 1.1,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final monthKey = months[group.x.toInt()];
                        final monthDate = DateTime.parse('$monthKey-01');
                        final monthName = DateFormat('MMM yyyy').format(monthDate);
                        return BarTooltipItem(
                          '$monthName\nAED ${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < months.length) {
                            final monthKey = months[index];
                            final monthDate = DateTime.parse('$monthKey-01');
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMM').format(monthDate),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Consumer<CurrencyService>(
                            builder: (context, currencyService, child) {
                              return Text(
                                currencyService.formatAmount(value),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: months.asMap().entries.map((entry) {
                    final index = entry.key;
                    final monthKey = entry.value;
                    final income = _monthlyIncome[monthKey] ?? 0.0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: income,
                          color: Colors.green,
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
