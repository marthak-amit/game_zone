#!/usr/bin/env bash
# Runs on an emulator: launch the release APK, play, and fail if the app crashed or froze.
# Every adb call has a hard timeout so a frozen emulator can never hang the job silently.
set -u
PKG=com.amit.sky_stack
A() { timeout "${T:-25}" adb "$@"; local rc=$?; [ $rc -eq 124 ] && echo "!! TIMEOUT: adb $*"; return $rc; }
say() { echo "[$(date +%H:%M:%S)] $*"; }

say "logcat -c";            A logcat -c
# Record logcat and host load continuously so evidence survives even if the emulator dies.
( adb logcat -v time > smoke_logcat.txt 2>&1 & )
( while true; do echo "--- $(date +%H:%M:%S)"; free -m | sed -n 2p; uptime; sleep 4; done > smoke_host.txt 2>&1 & )
say "install";              T=120 A install -r build/app/outputs/flutter-apk/app-release.apk
say "launch";               A shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 20
say "screen size";          SIZE=$(A shell wm size | grep -oE '[0-9]+x[0-9]+' | tail -1); W=${SIZE%x*}; H=${SIZE#*x}
say "screen ${W}x${H}"
say "screenshot menu";      timeout 25 adb exec-out screencap -p > smoke_menu.png
say "tap PLAY";             A shell input tap $((W/2)) $((H*41/100))
sleep 4
for i in 1 2 3 4 5 6 7 8 9 10; do A shell input tap $((W/2)) $((H/2)); sleep 1; done
say "screenshot game";      timeout 25 adb exec-out screencap -p > smoke_game.png

say "=== CPU (top) ===";       A shell top -n 1 -b 2>/dev/null | head -14
say "=== MEMORY ===";         A shell dumpsys meminfo $PKG 2>/dev/null | grep -E "TOTAL|Native Heap|Java Heap|Graphics|Views|Activities" | head -8
say "=== MEDIA PLAYERS (should stay small) ==="; A shell dumpsys media.player 2>/dev/null | grep -ciE "client|player" || true
say "=== ANR / FROZEN? ==="; A logcat -d | grep -iE "ANR in|Input dispatching timed out|not responding" | head -5
say "=== CRASH BUFFER ===";  A logcat -d -b crash | head -60
say "=== LOGCAT HIGHLIGHTS (recorded live) ==="; grep -E "FATAL|AndroidRuntime|E flutter|lowmemory|lmkd|Out of memory|OOM|Davey|Skipped [0-9]+ frames" smoke_logcat.txt | tail -25
say "=== HOST LOAD (tail) ==="; tail -12 smoke_host.txt
say "=== FLUTTER ERRORS ==="; A logcat -d -s flutter:E | tail -20
if A shell pidof $PKG; then say "SMOKE RESULT: APP RUNNING OK"; else say "SMOKE RESULT: APP NOT RUNNING"; exit 1; fi
