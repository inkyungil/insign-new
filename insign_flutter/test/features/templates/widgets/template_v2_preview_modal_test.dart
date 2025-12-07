import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insign/features/templates/widgets/template_v2_preview_modal.dart';
import 'package:insign/models/template_v2.dart';

void main() {
  group('TemplateV2PreviewModal', () {
    testWidgets(
      'renders A4 preview with template title',
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
          fieldSchema: const {
            'employee': {
              'name': {'required': true, 'type': 'string'},
            },
          },
          sampleData: const {
            'employee': {'name': '홍길동'},
          },
          version: 1,
          isActive: true,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TemplateV2PreviewModal(template: template),
            ),
          ),
        );

        expect(find.text('표준 근로계약서'), findsNWidgets(2));
        expect(find.byType(AspectRatio), findsOneWidget);
      },
    );
  });
}

