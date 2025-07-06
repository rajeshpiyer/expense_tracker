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
  Map<String, double> _monthlyIncome = {};
  Map<String, double> _monthlyExpenses = {};
  List<String> _months = [];
  int _currentMonthIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
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

    // Generate last 12 months
    final now = DateTime.now();
    _months = [];
    _monthlyIncome = {};
    _monthlyExpenses = {};

    for (int i = 11; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(monthDate);
      _months.add(monthKey);
      
      // Get transactions for this month
      final transactions = await _databaseHelper.getTransactionsByMonth(_currentUser!.id, monthKey);
      
      double income = 0.0;
      double expenses = 0.0;
      
      for (final transaction in transactions) {
        if (transaction.type == app_models.TransactionType.income) {
          income += transaction.amount;
        } else {
          expenses += transaction.amount;
        }
      }
      
      _monthlyIncome[monthKey] = income;
      _monthlyExpenses[monthKey] = expenses;
    }

    // Set current month index to show last 2 months by default
    _currentMonthIndex = _months.length - 2;
    if (_currentMonthIndex < 0) _currentMonthIndex = 0;
  }

  List<FlSpot> _getIncomeSpots(int startIndex) {
    final spots = <FlSpot>[];
    final endIndex = (startIndex + 2).clamp(0, _months.length);
    
    for (int i = startIndex; i < endIndex; i++) {
      final monthKey = _months[i];
      final income = _monthlyIncome[monthKey] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), income));
    }
    
    return spots;
  }

  List<FlSpot> _getExpenseSpots(int startIndex) {
    final spots = <FlSpot>[];
    final endIndex = (startIndex + 2).clamp(0, _months.length);
    
    for (int i = startIndex; i < endIndex; i++) {
      final monthKey = _months[i];
      final expenses = _monthlyExpenses[monthKey] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), expenses));
    }
    
    return spots;
  }

  List<FlSpot> _getLimitSpots(int startIndex, double monthlyLimit) {
    final spots = <FlSpot>[];
    final endIndex = (startIndex + 2).clamp(0, _months.length);
    
    for (int i = startIndex; i < endIndex; i++) {
      final monthKey = _months[i];
      final monthDate = DateTime.parse('$monthKey-01');
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
      final dailyLimit = monthlyLimit / daysInMonth;
      
      // Create a straight line for the month
      spots.add(FlSpot(i.toDouble(), monthlyLimit));
    }
    
    return spots;
  }

  String _getMonthLabel(int index) {
    if (index >= 0 && index < _months.length) {
      final monthKey = _months[index];
      final monthDate = DateTime.parse('$monthKey-01');
      return DateFormat('MMM yyyy').format(monthDate);
    }
    return '';
  }

  double _getMaxY() {
    double maxIncome = 0.0;
    double maxExpenses = 0.0;
    
    final endIndex = (_currentMonthIndex + 2).clamp(0, _months.length);
    for (int i = _currentMonthIndex; i < endIndex; i++) {
      final monthKey = _months[i];
      final income = _monthlyIncome[monthKey] ?? 0.0;
      final expenses = _monthlyExpenses[monthKey] ?? 0.0;
      
      if (income > maxIncome) maxIncome = income;
      if (expenses > maxExpenses) maxExpenses = expenses;
    }
    
    final maxValue = [maxIncome, maxExpenses].reduce((a, b) => a > b ? a : b);
    return maxValue * 1.2; // Add 20% padding
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
                        // Chart Title and Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Income vs Expenses',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _currentMonthIndex > 0
                                      ? () {
                                          setState(() {
                                            _currentMonthIndex--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                IconButton(
                                  onPressed: _currentMonthIndex < _months.length - 2
                                      ? () {
                                          setState(() {
                                            _currentMonthIndex++;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Chart
                        Consumer2<CurrencyService, ExpenseLimitService>(
                          builder: (context, currencyService, limitService, child) {
                            final maxY = _getMaxY();
                            if (maxY <= 0) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(
                                    child: Text(
                                      'No transaction data available',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              );
                            }

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    // Legend
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _LegendItem(
                                          color: Colors.green,
                                          label: 'Income',
                                        ),
                                        _LegendItem(
                                          color: Colors.red,
                                          label: 'Expenses',
                                        ),
                                        if (limitService.isEnabled)
                                          _LegendItem(
                                            color: const Color(0xFFFFD700),
                                            label: 'Limit',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Chart
                                    SizedBox(
                                      height: 300,
                                      child: LineChart(
                                        LineChartData(
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: true,
                                            horizontalInterval: maxY / 5,
                                            verticalInterval: 1,
                                            getDrawingHorizontalLine: (value) {
                                              return FlLine(
                                                color: Colors.grey[800]!,
                                                strokeWidth: 1,
                                              );
                                            },
                                            getDrawingVerticalLine: (value) {
                                              return FlLine(
                                                color: Colors.grey[800]!,
                                                strokeWidth: 1,
                                              );
                                            },
                                          ),
                                          titlesData: FlTitlesData(
                                            show: true,
                                            rightTitles: const AxisTitles(
                                              sideTitles: SideTitles(showTitles: false),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles: SideTitles(showTitles: false),
                                            ),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 30,
                                                interval: 1,
                                                getTitlesWidget: (value, meta) {
                                                  return SideTitleWidget(
                                                    axisSide: meta.axisSide,
                                                    child: Text(
                                                      _getMonthLabel(value.toInt()),
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                interval: maxY / 5,
                                                reservedSize: 60,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    currencyService.formatAmount(value),
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(
                                            show: true,
                                            border: Border.all(color: Colors.grey[800]!),
                                          ),
                                          minX: _currentMonthIndex.toDouble(),
                                          maxX: (_currentMonthIndex + 1).toDouble(),
                                          minY: 0,
                                          maxY: maxY,
                                          lineBarsData: [
                                            // Income line
                                            LineChartBarData(
                                              spots: _getIncomeSpots(_currentMonthIndex),
                                              isCurved: true,
                                              color: Colors.green,
                                              barWidth: 3,
                                              isStrokeCapRound: true,
                                              dotData: const FlDotData(show: true),
                                              belowBarData: BarAreaData(show: false),
                                            ),
                                            // Expenses line
                                            LineChartBarData(
                                              spots: _getExpenseSpots(_currentMonthIndex),
                                              isCurved: true,
                                              color: Colors.red,
                                              barWidth: 3,
                                              isStrokeCapRound: true,
                                              dotData: const FlDotData(show: true),
                                              belowBarData: BarAreaData(show: false),
                                            ),
                                            // Expense limit line
                                            if (limitService.isEnabled)
                                              LineChartBarData(
                                                spots: _getLimitSpots(_currentMonthIndex, limitService.monthlyLimit),
                                                isCurved: false,
                                                color: const Color(0xFFFFD700),
                                                barWidth: 2,
                                                isStrokeCapRound: true,
                                                dotData: const FlDotData(show: false),
                                                dashArray: [5, 5],
                                                belowBarData: BarAreaData(show: false),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
