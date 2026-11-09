import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_secretary/features/alarm/alarm_screen.dart';
import 'package:my_secretary/services/notification_service.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  const p = AlarmPayload(
    type: 'task',
    itemId: 7,
    notifId: 100007,
    title: '📝 مراجعة العقد',
    body: 'موعد الاستحقاق: اليوم',
  );

  test('ترميز بيانات المنبه وفكها', () {
    final d = AlarmPayload.decode(p.encode())!;
    expect(d.type, 'task');
    expect(d.itemId, 7);
    expect(d.notifId, 100007);
    expect(d.title, p.title);
    expect(AlarmPayload.decode('garbage'), isNull);
    expect(AlarmPayload.decode(null), isNull);
  });

  Future<AlarmAction?> openAndTap(WidgetTester tester, String button) async {
    AlarmAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await Navigator.push<AlarmAction>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AlarmScreen(payload: p, playSound: false),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('مراجعة العقد'), findsOneWidget);
    expect(find.text('تنبيه مهمة'), findsOneWidget);
    await tester.tap(find.text(button));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlarmScreen), findsNothing);
    return result;
  }

  testWidgets('زر الإيقاف يغلق المنبه', (tester) async {
    expect(await openAndTap(tester, 'إيقاف'), AlarmAction.dismiss);
  });

  testWidgets('زر التأجيل يعيد طلب التأجيل', (tester) async {
    expect(await openAndTap(tester, 'تأجيل 10 دقائق'), AlarmAction.snooze);
  });

  testWidgets('لا يمكن إغلاق المنبه بزر الرجوع', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AlarmScreen(payload: p, playSound: false)),
    );
    await tester.pump();
    final popped = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(popped, isTrue); // تم اعتراض الرجوع
    expect(find.byType(AlarmScreen), findsOneWidget);
  });
}
