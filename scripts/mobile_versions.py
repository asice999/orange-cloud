#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID_FILE = ROOT / "apps/android/app/build.gradle.kts"
IOS_FILE = ROOT / "apps/ios/Orange Cloud/Orange Cloud.xcodeproj/project.pbxproj"


def read_versions():
    android_text = ANDROID_FILE.read_text(encoding="utf-8")
    ios_text = IOS_FILE.read_text(encoding="utf-8")

    android_version_code_match = re.search(r'^\s*versionCode\s*=\s*(\d+)\s*$', android_text, re.MULTILINE)
    android_version_name_match = re.search(r'^\s*versionName\s*=\s*"([^"]+)"\s*$', android_text, re.MULTILINE)
    if not android_version_code_match or not android_version_name_match:
        raise SystemExit("Failed to parse Android version fields")

    ios_marketing_versions = sorted(set(re.findall(r'MARKETING_VERSION = ([0-9.]+);', ios_text)))
    ios_build_numbers = sorted(set(re.findall(r'CURRENT_PROJECT_VERSION = (\d+);', ios_text)))
    if len(ios_marketing_versions) != 1 or len(ios_build_numbers) != 1:
        raise SystemExit(
            f"Expected exactly one iOS MARKETING_VERSION and CURRENT_PROJECT_VERSION, got {ios_marketing_versions} / {ios_build_numbers}"
        )

    return {
        "android_version_code": int(android_version_code_match.group(1)),
        "android_version_name": android_version_name_match.group(1),
        "ios_marketing_version": ios_marketing_versions[0],
        "ios_build_number": int(ios_build_numbers[0]),
    }


def bump_patch(version: str) -> str:
    parts = [int(part) for part in version.split(".")]
    while len(parts) < 3:
        parts.append(0)
    parts[-1] += 1
    return ".".join(str(part) for part in parts)


def write_versions(next_versions):
    android_text = ANDROID_FILE.read_text(encoding="utf-8")
    android_text, android_code_count = re.subn(
        r'^(\s*versionCode\s*=\s*)\d+(\s*)$',
        rf'\g<1>{next_versions["android_version_code"]}\g<2>',
        android_text,
        count=1,
        flags=re.MULTILINE,
    )
    android_text, android_name_count = re.subn(
        r'^(\s*versionName\s*=\s*")([^"]+)("\s*)$',
        rf'\g<1>{next_versions["android_version_name"]}\g<3>',
        android_text,
        count=1,
        flags=re.MULTILINE,
    )
    if android_code_count != 1 or android_name_count != 1:
        raise SystemExit("Failed to update Android version fields")
    ANDROID_FILE.write_text(android_text, encoding="utf-8")

    ios_text = IOS_FILE.read_text(encoding="utf-8")
    ios_text, marketing_count = re.subn(
        r'MARKETING_VERSION = [0-9.]+;',
        f'MARKETING_VERSION = {next_versions["ios_marketing_version"]};',
        ios_text,
    )
    ios_text, build_count = re.subn(
        r'CURRENT_PROJECT_VERSION = \d+;',
        f'CURRENT_PROJECT_VERSION = {next_versions["ios_build_number"]};',
        ios_text,
    )
    if marketing_count < 1 or build_count < 1:
        raise SystemExit("Failed to update iOS version fields")
    IOS_FILE.write_text(ios_text, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in {"read", "bump"}:
        raise SystemExit("Usage: mobile_versions.py [read|bump]")

    current = read_versions()
    if sys.argv[1] == "read":
        print(json.dumps(current, ensure_ascii=True))
    else:
        next_versions = {
            "android_version_code": current["android_version_code"] + 1,
            "android_version_name": bump_patch(current["android_version_name"]),
            "ios_marketing_version": bump_patch(current["ios_marketing_version"]),
            "ios_build_number": current["ios_build_number"] + 1,
        }
        write_versions(next_versions)
        print(json.dumps({"current": current, "next": next_versions}, ensure_ascii=True))
