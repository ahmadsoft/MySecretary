#!/usr/bin/env python3
"""ينقل مرحلة "Embed Foundation Extensions" قبل "Thin Binary" في هدف Runner.

بدون ذلك يظهر خطأ Xcode المعروف: "Cycle inside Runner" عند إضافة Widget Extension
لتطبيق Flutter. الاستخدام: python3 tool/fix_build_phases.py ios/Runner.xcodeproj/project.pbxproj
"""
import re
import sys


def fix(text: str) -> tuple[str, bool]:
    # قسم هدف Runner فقط
    m = re.search(r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;.*?buildPhases = \((.*?)\);', text, re.S)
    if not m:
        raise SystemExit('لم أجد هدف Runner في ملف المشروع.')
    phases = m.group(1)
    lines = [l for l in phases.split('\n') if l.strip()]
    embed = next((l for l in lines if 'Embed Foundation Extensions' in l or 'Embed App Extensions' in l), None)
    thin = next((l for l in lines if 'Thin Binary' in l), None)
    if embed is None or thin is None:
        return text, False
    if lines.index(embed) < lines.index(thin):
        return text, False
    lines.remove(embed)
    lines.insert(lines.index(thin), embed)
    new_phases = '\n' + '\n'.join(lines) + '\n\t\t\t'
    return text[:m.start(1)] + new_phases + text[m.end(1):], True


if __name__ == '__main__':
    path = sys.argv[1]
    with open(path, encoding='utf-8') as f:
        original = f.read()
    updated, changed = fix(original)
    if changed:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(updated)
        print('✓ تم ترتيب مراحل البناء (Embed Foundation Extensions قبل Thin Binary).')
    else:
        print('✓ ترتيب مراحل البناء سليم.')
