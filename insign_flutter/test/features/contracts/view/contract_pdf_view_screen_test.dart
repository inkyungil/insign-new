import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insign/features/contracts/view/contract_pdf_view_screen.dart';

void main() {
  group('ContractPdfViewScreen', () {
    testWidgets('renders app bar and loading indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ContractPdfViewScreen(
            contractId: 1,
            autoLoad: false,
          ),
        ),
      );

      expect(find.text('계약서 PDF'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

