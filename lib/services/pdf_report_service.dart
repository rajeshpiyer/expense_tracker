import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as app_models;
import '../models/user.dart';
import '../database/database_helper.dart';
import '../services/currency_service.dart';

class PdfReportService {
  static const String _reportTitle = 'FinanceFlow - Monthly Transaction Report';
  
  /// Generate PDF report for the last 30 days of transactions
  static Future<File> generateMonthlyReport({
    required User user,
    required CurrencyService currencyService,
  }) async {
    try {
      if (kDebugMode) {
        print('Starting PDF report generation for user: ${user.email}');
      }

      // Get transactions for the last 30 days
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));
      
      final dbHelper = DatabaseHelper();
      final transactions = await dbHelper.getTransactionsByDateRange(
        user.id,
        startDate,
        endDate,
      );

      if (kDebugMode) {
        print('Found ${transactions.length} transactions for the last 30 days');
      }

      // Calculate summary data
      final summary = _calculateSummary(transactions);
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Add pages to PDF
      await _addCoverPage(pdf, user, startDate, endDate, summary, currencyService);
      await _addTransactionPages(pdf, transactions, currencyService);
      await _addSummaryPage(pdf, summary, currencyService);

      // Save PDF to file
      final file = await _savePdfToFile(pdf, user.email);
      
      if (kDebugMode) {
        print('PDF report generated successfully: ${file.path}');
      }
      
      return file;
    } catch (e) {
      if (kDebugMode) {
        print('Error generating PDF report: $e');
      }
      rethrow;
    }
  }

  /// Calculate summary statistics for transactions
  static Map<String, dynamic> _calculateSummary(List<app_models.Transaction> transactions) {
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> categoryTotals = {};

    for (final transaction in transactions) {
      if (transaction.type == app_models.TransactionType.income) {
        totalIncome += transaction.amount;
      } else {
        // Expenses are stored as negative amounts, so we add them directly
        totalExpense += transaction.amount;
      }

      // Track category totals (always use absolute values for category breakdown)
      final category = transaction.category;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + transaction.amount.abs();
    }

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense.abs(), // Convert to positive for display
      'balance': totalIncome + totalExpense, // totalExpense is negative, so this gives correct balance
      'transactionCount': transactions.length,
      'categoryTotals': categoryTotals,
      'topCategory': categoryTotals.isNotEmpty
          ? categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : 'None',
    };
  }

  /// Add cover page to PDF
  static Future<void> _addCoverPage(
    pw.Document pdf,
    User user,
    DateTime startDate,
    DateTime endDate,
    Map<String, dynamic> summary,
    CurrencyService currencyService,
  ) async {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey900,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _reportTitle,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Generated on ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey300,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // User Information
              pw.Text(
                'Report Details',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 15),
              
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('User:', user.name),
                        _buildInfoRow('Email:', user.email),
                        _buildInfoRow('Report Period:', 
                          '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}'),
                        _buildInfoRow('Total Transactions:', '${summary['transactionCount']}'),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Financial Summary
              pw.Text(
                'Financial Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 15),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _buildSummaryRow('Total Income:',
                      currencyService.formatAmountForPdf(summary['totalIncome']),
                      PdfColors.green),
                    pw.SizedBox(height: 8),
                    _buildSummaryRow('Total Expenses:',
                      currencyService.formatAmountForPdf(summary['totalExpense']),
                      PdfColors.red),
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    _buildSummaryRow('Net Balance:',
                      currencyService.formatAmountForPdf(summary['balance']),
                      summary['balance'] >= 0 ? PdfColors.green : PdfColors.red),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Top Category
              if (summary['topCategory'] != 'None') ...[
                pw.Text(
                  'Top Spending Category: ${summary['topCategory']}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Build info row for PDF
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  /// Build summary row for PDF
  static pw.Widget _buildSummaryRow(String label, String value, PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Add transaction pages to PDF
  static Future<void> _addTransactionPages(
    pw.Document pdf,
    List<app_models.Transaction> transactions,
    CurrencyService currencyService,
  ) async {
    if (transactions.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(
                'No transactions found for the selected period.',
                style: pw.TextStyle(fontSize: 16),
              ),
            );
          },
        ),
      );
      return;
    }

    // Group transactions by date
    final groupedTransactions = <String, List<app_models.Transaction>>{};
    for (final transaction in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      groupedTransactions.putIfAbsent(dateKey, () => []).add(transaction);
    }

    // Sort dates in descending order (newest first)
    final sortedDates = groupedTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // Create all transaction widgets first
    List<pw.Widget> allTransactionWidgets = [];

    for (final dateKey in sortedDates) {
      final dayTransactions = groupedTransactions[dateKey]!;
      final date = DateTime.parse(dateKey);

      // Add date header
      allTransactionWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 15, bottom: 10),
          child: pw.Text(
            DateFormat('EEEE, MMMM dd, yyyy').format(date),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
      );

      // Add transactions for this date
      for (final transaction in dayTransactions) {
        allTransactionWidgets.add(
          _buildTransactionRow(transaction, currencyService),
        );
      }
    }

    // Now paginate the widgets
    const int itemsPerPage = 20; // Reduced to ensure content fits on page
    int currentIndex = 0;

    while (currentIndex < allTransactionWidgets.length) {
      final endIndex = (currentIndex + itemsPerPage).clamp(0, allTransactionWidgets.length);
      final pageWidgets = allTransactionWidgets.sublist(currentIndex, endIndex);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Transaction Details',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: pageWidgets,
                  ),
                ),
              ],
            );
          },
        ),
      );

      currentIndex = endIndex;
    }
  }

  /// Build transaction row for PDF
  static pw.Widget _buildTransactionRow(
    app_models.Transaction transaction,
    CurrencyService currencyService,
  ) {
    final isIncome = transaction.type == app_models.TransactionType.income;
    final color = isIncome ? PdfColors.green : PdfColors.red;
    final sign = isIncome ? '+' : '-';
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  transaction.category,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (transaction.description != null && transaction.description!.isNotEmpty)
                  pw.Text(
                    transaction.description!,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              '$sign${currencyService.formatAmountForPdf(transaction.amount.abs())}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Add summary page to PDF
  static Future<void> _addSummaryPage(
    pw.Document pdf,
    Map<String, dynamic> summary,
    CurrencyService currencyService,
  ) async {
    final categoryTotals = summary['categoryTotals'] as Map<String, double>;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Category Breakdown',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              if (categoryTotals.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: categoryTotals.entries.map((entry) {
                      return pw.Container(
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              entry.key,
                              style: pw.TextStyle(fontSize: 12),
                            ),
                            pw.Text(
                              currencyService.formatAmountForPdf(entry.value),
                              style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                pw.Text(
                  'No category data available.',
                  style: pw.TextStyle(fontSize: 14),
                ),
              ],

              pw.SizedBox(height: 30),

              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Generated by FinanceFlow',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Intelligent financial management at your fingertips',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Save PDF to file
  static Future<File> _savePdfToFile(pw.Document pdf, String userEmail) async {
    final output = await pdf.save();

    // Get the app's documents directory
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'FinanceFlow_Report_$timestamp.pdf';
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(output);
    return file;
  }
}
