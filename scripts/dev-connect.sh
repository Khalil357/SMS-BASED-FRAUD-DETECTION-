#!/usr/bin/env bash
# Connect this phone to the local backend over the USB cable.
#
# The app auto-discovers the backend (127.0.0.1 via `adb reverse`, the
# computer's LAN IP over WiFi, or 10.0.2.2 on the emulator), so ordinary
# builds work without any defines. Unplugging/replugging the phone clears
# the `adb reverse` forward - run this script again to restore it.
#
# Usage:
#   ./scripts/dev-connect.sh                 # set forward + rebuild + install
#   RECONNECT_ONLY=1 ./scripts/dev-connect.sh  # just restore the forward + relaunch
#   ./scripts/dev-connect.sh <device-id>     # target a specific adb device
set -euo pipefail

DEVICE=${1:-}
FLUTTER=${FLUTTER:-flutter}
PKG=com.example.sms_based_fraud_detection

if [ -n "$DEVICE" ]; then
  SELECTOR=(-s "$DEVICE")
else
  SELECTOR=()
fi

echo "Checking backend is up..."
# The API is auth-guarded, so ANY HTTP status (incl. 401) means it is up.
CODE=$(curl -s -m 3 -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/api/health || true)
if [ "$CODE" = "000" ]; then
  echo "Backend not reachable at http://127.0.0.1:8080 (is 'docker compose up' running?)." >&2
  exit 1
fi
echo "Backend responded (HTTP $CODE)."

echo "Waiting for a device..."
adb "${SELECTOR[@]}" wait-for-device

echo "Setting USB reverse forward 8080 -> host 8080..."
adb "${SELECTOR[@]}" reverse tcp:8080 tcp:8080

if [ "${RECONNECT_ONLY:-0}" = "1" ]; then
  echo "Reconnect-only: relaunching the installed app..."
  adb "${SELECTOR[@]}" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
  echo "Done. Forward restored; app relaunched."
  exit 0
fi

echo "Building and installing the debug APK..."
$FLUTTER build apk --debug
adb "${SELECTOR[@]}" install -r build/app/outputs/flutter-apk/app-debug.apk

echo "Launching..."
adb "${SELECTOR[@]}" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true

echo "Done. Login goes through the USB tunnel to the backend."
