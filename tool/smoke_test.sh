#!/usr/bin/env bash
# Installs the release APK on the running emulator, opens it, and fails if the
# app crashes or stops within 25 seconds. Saves logcat and a screenshot.
set -u
APK=${1:-build/app/outputs/flutter-apk/app-release.apk}
PKG=com.aksharaaata.kannada
mkdir -p smoke
adb install -r "$APK"
adb logcat -c
adb shell am start -W -n "$PKG/com.aksharaaata.akshara_aata.MainActivity"
sleep 25
adb exec-out screencap -p > smoke/screen.png || true
adb logcat -d > smoke/logcat.txt
echo "----- crash lines -----"
grep -E "FATAL EXCEPTION|AndroidRuntime|Fatal signal|F DEBUG|F libc|E flutter|Abort message|Caused by" -A 25 smoke/logcat.txt | head -200 || true
echo "-----------------------"
if adb shell pidof "$PKG" >/dev/null; then
  echo "App is running after 25 s."
else
  echo "::error::App is not running: it crashed or closed on launch."
  exit 1
fi
