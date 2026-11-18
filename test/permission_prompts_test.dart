import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_secretary/features/permissions/permission_prompts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<bool?> run(WidgetTester tester, String button) async {
    SharedPreferences.setMockInitialValues({});
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async =>
                result = await showSmsProminentDisclosure(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // الإفصاح يذكر ماذا يُقرأ وأين يُحفظ
    expect(find.text('قراءة رسائل البنوك'), findsOneWidget);
    expect(find.textContaining('على جهازك فقط'), findsOneWidget);
    expect(find.textContaining('رموز التحقق'), findsOneWidget);
    await tester.ensureVisible(find.text(button));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('الموافقة على الإفصاح تسمح بطلب الإذن', (tester) async {
    expect(await run(tester, 'أوافق، متابعة'), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool('sms_consent'),
      isTrue,
    );
  });

  testWidgets('الرفض لا يطلب الإذن', (tester) async {
    expect(await run(tester, 'ليس الآن'), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool('sms_consent'),
      isFalse,
    );
  });
}
