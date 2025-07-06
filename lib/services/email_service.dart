import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';

class EmailService {
  // Pre-configured SMTP settings for Gmail
  static const String _smtpHost = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const String _username = 'prajeshiyer@gmail.com';
  static const String _password = 'myaz riph wcun qtgt';
  static const bool _useSSL = true;

  /// Check if email service is configured (always true now)
  static bool get isConfigured => true;

  /// Send PDF report via email
  static Future<bool> sendPdfReport({
    required User user,
    required File pdfFile,
    String? customSubject,
    String? customMessage,
  }) async {
    if (kDebugMode) {
      print('Sending PDF report to: ${user.email}');
      print('PDF file: ${pdfFile.path}');
      print('File size: ${await pdfFile.length()} bytes');
    }

    // Create email message
    final message = await _createEmailMessage(
      user: user,
      pdfFile: pdfFile,
      customSubject: customSubject,
      customMessage: customMessage,
    );

    // Try different SMTP configurations
    final configurations = [
      // Configuration 1: STARTTLS on port 587
      {
        'name': 'Gmail STARTTLS (587)',
        'server': SmtpServer(
          _smtpHost,
          port: 587,
          ssl: false,
          allowInsecure: false,
          username: _username,
          password: _password,
        ),
      },
      // Configuration 2: SSL on port 465
      {
        'name': 'Gmail SSL (465)',
        'server': SmtpServer(
          _smtpHost,
          port: 465,
          ssl: true,
          allowInsecure: false,
          username: _username,
          password: _password,
        ),
      },
      // Configuration 3: Insecure fallback
      {
        'name': 'Gmail Insecure Fallback (587)',
        'server': SmtpServer(
          _smtpHost,
          port: 587,
          ssl: false,
          allowInsecure: true,
          username: _username,
          password: _password,
        ),
      },
    ];

    // Try each configuration
    for (final config in configurations) {
      try {
        if (kDebugMode) {
          print('Trying ${config['name']}...');
        }

        final sendReport = await send(message, config['server'] as SmtpServer);

        if (kDebugMode) {
          print('Email sent successfully using ${config['name']}!');
          print('Message ID: ${sendReport.toString()}');
        }

        return true;
      } catch (e) {
        if (kDebugMode) {
          print('Failed with ${config['name']}: $e');
        }
        // Continue to next configuration
      }
    }

    // If all configurations failed
    throw Exception('Failed to send email with all SMTP configurations');
  }

  /// Create email message with PDF attachment
  static Future<Message> _createEmailMessage({
    required User user,
    required File pdfFile,
    String? customSubject,
    String? customMessage,
  }) async {
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final fileName = pdfFile.path.split('/').last;
    
    // Default subject and message
    final subject = customSubject ?? 'FinanceFlow - Monthly Transaction Report ($currentDate)';
    final htmlMessage = customMessage ?? _getDefaultEmailTemplate(user.name, currentDate);

    // PDF file will be attached directly

    return Message()
      ..from = Address(_username, 'FinanceFlow')
      ..recipients.add(user.email)
      ..subject = subject
      ..html = htmlMessage
      ..attachments = [
        FileAttachment(
          pdfFile,
          fileName: fileName,
          contentType: 'application/pdf',
        ),
      ];
  }

  /// Get default email template
  static String _getDefaultEmailTemplate(String userName, String currentDate) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FinanceFlow Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            background: linear-gradient(135deg, #1a1a1a 0%, #333333 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            margin-bottom: 30px;
        }
        .header h1 {
            margin: 0;
            font-size: 24px;
            font-weight: bold;
        }
        .header p {
            margin: 5px 0 0 0;
            opacity: 0.9;
            font-size: 14px;
        }
        .content {
            margin-bottom: 30px;
        }
        .highlight {
            background-color: #FFD700;
            color: #1a1a1a;
            padding: 2px 6px;
            border-radius: 4px;
            font-weight: bold;
        }
        .footer {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border-left: 4px solid #FFD700;
        }
        .footer p {
            margin: 0;
            color: #666;
            font-size: 14px;
        }
        .attachment-info {
            background-color: #e8f5e8;
            border: 1px solid #c3e6c3;
            border-radius: 6px;
            padding: 15px;
            margin: 20px 0;
        }
        .attachment-info strong {
            color: #2d5a2d;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>FinanceFlow</h1>
            <p>Intelligent financial management at your fingertips</p>
        </div>
        
        <div class="content">
            <h2>Hello $userName!</h2>
            
            <p>Your monthly transaction report has been generated and is ready for review.</p>
            
            <div class="attachment-info">
                <strong>📄 Report Details:</strong><br>
                • <strong>Period:</strong> Last 30 days<br>
                • <strong>Generated:</strong> $currentDate<br>
                • <strong>Format:</strong> PDF Document<br>
                • <strong>Contains:</strong> All your transactions, financial summary, and category breakdown
            </div>
            
            <p>This comprehensive report includes:</p>
            <ul>
                <li><strong>Financial Summary:</strong> Your income, expenses, and net balance</li>
                <li><strong>Transaction Details:</strong> Complete list of all transactions</li>
                <li><strong>Category Breakdown:</strong> Spending analysis by category</li>
                <li><strong>Professional Formatting:</strong> Clean, easy-to-read layout</li>
            </ul>
            
            <p>The report is attached as a <span class="highlight">PDF file</span> that you can save, print, or share as needed.</p>
            
            <p>Thank you for using FinanceFlow to manage your finances!</p>
        </div>
        
        <div class="footer">
            <p><strong>FinanceFlow</strong> - Your trusted financial companion</p>
            <p>This email was automatically generated by your FinanceFlow app.</p>
        </div>
    </div>
</body>
</html>
    ''';
  }

  /// Test email configuration
  static Future<bool> testConfiguration() async {
    try {
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        ssl: false, // Use STARTTLS instead of SSL
        allowInsecure: false,
        username: _username,
        password: _password,
      );

      // Create a simple test message
      final message = Message()
        ..from = Address(_username, 'FinanceFlow')
        ..recipients.add(_username) // Send to self for testing
        ..subject = 'FinanceFlow - Email Configuration Test'
        ..text = 'This is a test email to verify your SMTP configuration is working correctly.';

      await send(message, smtpServer);

      if (kDebugMode) {
        print('Email configuration test successful!');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Email configuration test failed: $e');
      }
      return false;
    }
  }

  /// Get current configuration status
  static Map<String, dynamic> getConfigurationStatus() {
    return {
      'isConfigured': isConfigured,
      'smtpHost': _smtpHost,
      'smtpPort': _smtpPort,
      'username': _username,
      'useSSL': _useSSL,
    };
  }
}
