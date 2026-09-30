#!/usr/bin/env bash
# Runs on an emulator: launch the release APK, play a few taps, fail if the app crashed.
set -u
PKG=com.amit.sky_stack
adb logcat -c
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 20
SIZE=$(adb shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1); W=${SIZE%x*}; H=${SIZE#*x}
echo "screen ${W}x${H}"
adb exec-out screencap -p > smoke_menu.png
echo "=== tap PLAY and play ==="
adb shell input tap $((W/2)) $((H*41/100))
sleep 4
for i in 1 2 3 4 5 6 7 8 9 10; do adb shell input tap $((W/2)) $((H/2)); sleep 1; done
adb exec-out screencap -p > smoke_game.png
echo "=== CRASH BUFFER ==="; adb logcat -d -b crash | head -60
echo "=== FLUTTER ERRORS ==="; adb logcat -d -s flutter:E | tail -20
if adb shell pidof $PKG; then echo "SMOKE RESULT: APP RUNNING OK"; else echo "SMOKE RESULT: APP NOT RUNNING"; exit 1; fi
