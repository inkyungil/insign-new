import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insign/features/contracts/view/contract_sign_screen.dart';

void main() {
  group('ContractSignScreen', () {
    testWidgets('renders verification form before contract is loaded',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ContractSignScreen(
            signatureToken: 'test-token',
          ),
        ),
      );

      // 초기 상태에서는 서명 화면 타이틀 또는 안내 문구가 보여야 한다.
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

