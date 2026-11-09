#!/bin/bash
# إعداد منبه النظام (AlarmKit) لـ iOS 26 — يُشغَّل على جهاز Mac من مجلد المشروع.
#
# قبل التشغيل (خطوة واحدة يدوية في Xcode):
#   1. افتح ios/Runner.xcworkspace
#   2. File ← New ← Target ← Widget Extension
#   3. الاسم: AlarmWidget   (حدد Live Activity فقط وألغِ أي خيار آخر) ← Finish ← Activate
#   4. أغلق Xcode تماماً (⌘Q) ثم شغّل:  bash tool/setup_alarmkit.sh
set -e
cd "$(dirname "$0")/.."

EXT=ios/AlarmWidget
if [ ! -d "$EXT" ]; then
  echo "✗ لم أجد المجلد $EXT"
  echo "  أنشئ أولاً Widget Extension باسم AlarmWidget في Xcode (انظر أعلى هذا الملف)."
  exit 1
fi
if pgrep -x Xcode >/dev/null; then
  echo "✗ أغلق Xcode أولاً (⌘Q) ثم أعد تشغيل الأمر."
  exit 1
fi

echo "• تحديث المكتبات..."
flutter pub get >/dev/null

echo "• حذف الملفات النموذجية التي أنشأها Xcode..."
for f in AlarmWidget.swift AlarmWidgetLiveActivity.swift AlarmWidgetControl.swift AppIntent.swift AlarmWidgetBundle.swift; do
  rm -f "$EXT/$f"
done

echo "• نسخ ملفات المنبه إلى الإضافة..."
dart run alarm_kit:setup --extension "$EXT"

cat > "$EXT/AlarmWidgetBundle.swift" <<'SWIFT'
import SwiftUI
import WidgetKit

@main
struct AlarmWidgetBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOSApplicationExtension 26.0, *) {
      AlarmLiveActivity()
    }
  }
}
SWIFT
echo "✓ كتبت $EXT/AlarmWidgetBundle.swift"

echo "• ترتيب مراحل البناء..."
python3 tool/fix_build_phases.py ios/Runner.xcodeproj/project.pbxproj

echo "• الفحص النهائي:"
dart run alarm_kit:setup --doctor || true

# Xcode 16 وما بعده ينشئ مجلد الإضافة "متزامناً": كل ملفات Swift داخله تُضاف للهدف تلقائياً،
# لكن فاحص alarm_kit لا يتعرف على هذا النوع فيُظهر علامتي ✗ عن Target Membership.
if grep -q "PBXFileSystemSynchronizedRootGroup" ios/Runner.xcodeproj/project.pbxproj \
   && grep -q "path = AlarmWidget;" ios/Runner.xcodeproj/project.pbxproj; then
  echo
  echo "ℹ️  مجلد AlarmWidget متزامن مع هدف الإضافة، فالملفات مضافة تلقائياً."
  echo "   علامتا ✗ عن Target Membership أعلاه متوقعتان ويمكن تجاهلهما."
fi

echo
echo "✓ انتهى الإعداد. الخطوات التالية:"
echo "  1. افتح ios/Runner.xcworkspace واختر هدف AlarmWidgetExtension ← Signing & Capabilities ← اختر نفس الـ Team."
echo "  2. شغّل التطبيق:  flutter run --release"
echo "  3. في التطبيق: المزيد ← الإعدادات ← فعّل \"منبه النظام (iOS 26)\" ووافق على الإذن."
