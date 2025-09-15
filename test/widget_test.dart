// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mydent_app/main.dart';
import 'package:mydent_app/auth/auth_provider.dart';
import 'package:mydent_app/models/staff_model.dart';
 

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots with Provider and shows a Scaffold', (WidgetTester tester) async {
    // Prepare provider in logged-in state to avoid LoginScreen (which touches Firebase)
    final auth = AppAuthProvider();
    auth.setStaffLoggedIn(
      // Role other than admin/dentist/officer => HomeGuestScreen (no Firebase)
      Staff(id: 't1', name: 'Tester', username: 'tester', role: 'guest'),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MyApp(),
      ),
    );

    // Allow initial build and in-app splash timer (3s) to complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
