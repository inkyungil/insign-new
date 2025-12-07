import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insign/features/templates/view/template_pdf_view_screen.dart';

void main() {
  group('TemplatePdfViewScreen', () {
    testWidgets('renders app bar and loading indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TemplatePdfViewScreen(
            templateId: 1,
          ),
        ),
      );

      expect(find.text('템플릿 PDF 미리보기'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

