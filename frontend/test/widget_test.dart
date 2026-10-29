import 'package:dental_clinic/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Vikare theme renders a clinic screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: Text('Vikare Dental Clinic'))),
      ),
    );

    expect(find.text('Vikare Dental Clinic'), findsOneWidget);
  });
}
