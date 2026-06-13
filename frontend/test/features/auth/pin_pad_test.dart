import 'package:dental_clinic/features/auth/presentation/widgets/pin_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PinPad sends digit taps', (tester) async {
    String? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: PinPad(
                onDigit: (digit) => tapped = digit,
                onDelete: () {},
                canSubmit: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('5'));
    expect(tapped, '5');
  });

  testWidgets('PinPad sends delete taps', (tester) async {
    var deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: PinPad(
                onDigit: (_) {},
                onDelete: () => deleted = true,
                canSubmit: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).last);
    expect(deleted, isTrue);
  });
}
