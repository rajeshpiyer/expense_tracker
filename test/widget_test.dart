// This is a basic Flutter widget test for the Expense Tracker app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financeflow/main.dart';

void main() {
  testWidgets('FinanceFlow app loads login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FinanceFlowApp());

    // Verify that the login screen loads with the app title.
    expect(find.text('FinanceFlow'), findsOneWidget);

    // Verify that the Google sign-in button is present.
    expect(find.text('Sign in with Google'), findsOneWidget);

    // Verify that the app logo/icon is present.
    expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);

    // Verify that features section is present.
    expect(find.text('Features:'), findsOneWidget);
    expect(find.text('Secure Google Sign-In'), findsOneWidget);
    expect(find.text('Local data storage'), findsOneWidget);
    expect(find.text('Track income & expenses'), findsOneWidget);
    expect(find.text('Categorize transactions'), findsOneWidget);
  });
}
