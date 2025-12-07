import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insign/features/templates/widgets/previews/employment_template_preview.dart';
import 'package:insign/models/template_v2.dart';

void main() {
  group('EmploymentTemplatePreview', () {
    testWidgets('renders standard employment contract layout',
        (WidgetTester tester) async {
      final template = TemplateV2(
        id: 1,
        type: 'employment',
        name: 'Employment Contract',
        displayName: '표준 근로계약서',
        description: '테스트용 근로 계약서 설명',
        category: '근로',
        icon: 'work',
        color: Colors.blue,
        screenRoute: '/contracts-v2/employment/create',
        fieldSchema: const {},
        sampleData: const {},
        version: 1,
        isActive: true,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmploymentTemplatePreview(template: template),
          ),
        ),
      );

      expect(find.text('표준 근로계약서'), findsOneWidget);
      expect(find.text('근로자 정보'), findsOneWidget);
      expect(find.text('사용자(사업주) 정보'), findsOneWidget);
    });
  });
}

