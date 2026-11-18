#!/usr/bin/env python3
"""يضيف ios/Runner/PrivacyInfo.xcprivacy إلى هدف Runner في مشروع Xcode (مرة واحدة، آمن للتكرار).

الاستخدام من مجلد المشروع:  python3 tool/add_privacy_manifest.py
"""
import hashlib
import re
import sys

PATH = 'ios/Runner.xcodeproj/project.pbxproj'


def uid(name: str) -> str:
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


def add(s: str) -> str:
    if 'PrivacyInfo.xcprivacy' in s:
        return s
    fr, bf = uid('privacyinfo-fileref'), uid('privacyinfo-buildfile')
    s = s.replace('/* Begin PBXBuildFile section */',
                  '/* Begin PBXBuildFile section */\n'
                  f'\t\t{bf} /* PrivacyInfo.xcprivacy in Resources */ = {{isa = PBXBuildFile; '
                  f'fileRef = {fr} /* PrivacyInfo.xcprivacy */; }};', 1)
    s = s.replace('/* Begin PBXFileReference section */',
                  '/* Begin PBXFileReference section */\n'
                  f'\t\t{fr} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; '
                  'path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; };', 1)
    # مجموعة Runner (بجانب Info.plist)
    m = re.search(r'/\* Runner \*/ = \{\s*isa = PBXGroup;\s*children = \((.*?)\);', s, re.S)
    if not m:
        sys.exit('لم أجد مجموعة Runner في المشروع.')
    info = re.search(r'\n(\t+)\w{24} /\* Info\.plist \*/,', m.group(1))
    if not info:
        sys.exit('لم أجد Info.plist داخل مجموعة Runner.')
    children = m.group(1).replace(info.group(0), info.group(0) + f'\n{info.group(1)}{fr} /* PrivacyInfo.xcprivacy */,', 1)
    s = s[:m.start(1)] + children + s[m.end(1):]
    # مرحلة Resources الخاصة بهدف Runner
    t = re.search(r'/\* Runner \*/ = \{\s*isa = PBXNativeTarget;.*?buildPhases = \((.*?)\);', s, re.S)
    rid = re.search(r'(\w{24}) /\* Resources \*/', t.group(1)).group(1)
    r = re.search(re.escape(rid) + r' /\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;.*?files = \((.*?)\);', s, re.S)
    if not r:
        sys.exit('لم أجد مرحلة Resources لهدف Runner.')
    s = s[:r.start(1)] + r.group(1).rstrip() + f'\n\t\t\t\t{bf} /* PrivacyInfo.xcprivacy in Resources */,\n\t\t\t' + s[r.end(1):]
    return s


if __name__ == '__main__':
    with open(PATH, encoding='utf-8') as f:
        original = f.read()
    updated = add(original)
    if updated == original:
        print('✓ ملف الخصوصية PrivacyInfo.xcprivacy مضاف للمشروع مسبقاً.')
    else:
        if updated.count('{') != updated.count('}') or updated.count('(') != updated.count(')'):
            sys.exit('✗ توقفت: الناتج غير متوازن، لم يُعدَّل الملف.')
        with open(PATH, 'w', encoding='utf-8') as f:
            f.write(updated)
        print('✓ أُضيف PrivacyInfo.xcprivacy إلى هدف Runner.')
