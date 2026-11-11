#!/usr/bin/env bash
# Builds the investor-demo artifacts this Linux machine can make (ADR 0127,
# docs/INVESTOR_DEMO.md): Linux release, web release and an Android APK.
# Windows, macOS and iOS build in GitHub Actions (.github/workflows/).
#
#   tool/build_demo.sh [HOST] [linux|web|apk ...]
#
# HOST is where the demo backend answers: the laptop's LAN address, e.g.
# 192.168.0.16, with the dev-stack's :8000 and :8001 bound to it. It
# defaults to this machine's first LAN address. A release build refuses a
# loopback address (release_config_guard.dart), so for the laptop alone
# use the :8080 preview instead.
#
# Builds the committed HEAD from a separate git worktree, so other
# sessions' uncommitted edits never reach a demo build. Output goes to
# build/demo/<platform>/. Android needs JAVA_HOME and ANDROID_HOME (see
# INVESTOR_DEMO.md); the APK allows cleartext HTTP to any host
# (TUTOLYS_DEMO_LAN=1), so never publish it.
set -euo pipefail

HOST="${1:-$(hostname -I | awk '{print $1}')}"
shift || true
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(linux web apk)

APP="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$APP/build/demo-src"
OUT="$APP/build/demo"
REV="$(git -C "$APP" rev-parse HEAD)"

if [ ! -e "$SRC/.git" ]; then
  git -C "$APP" worktree add --detach "$SRC" "$REV" >/dev/null
else
  git -C "$SRC" checkout --detach --quiet "$REV"
fi
cd "$SRC"
SHA="$(git rev-parse --short HEAD)"
flutter pub get >/dev/null

DEFINES=(
  --dart-define=TUTOLYS_API_BASE="http://$HOST:8000"
  --dart-define=TUTOLYS_TELEMETRY_BASE="http://$HOST:8001"
  --dart-define=TUTOLYS_GIT_SHA="$SHA"
)
mkdir -p "$OUT"

for target in "${TARGETS[@]}"; do
  case "$target" in
    linux)
      flutter build linux --release "${DEFINES[@]}"
      rm -rf "$OUT/linux" && mkdir -p "$OUT/linux"
      cp -r build/linux/x64/release/bundle "$OUT/linux/tutolys"
      tar -C "$OUT/linux" -czf "$OUT/tutolys-linux-x64-$SHA.tar.gz" tutolys
      ;;
    web)
      flutter build web --release "${DEFINES[@]}" -o "$OUT/web"
      ;;
    apk)
      TUTOLYS_DEMO_LAN=1 flutter build apk --release "${DEFINES[@]}"
      cp build/app/outputs/flutter-apk/app-release.apk \
        "$OUT/tutolys-android-$SHA.apk"
      ;;
    *)
      echo "unknown target: $target" >&2
      exit 2
      ;;
  esac
  echo "built $target at $SHA for $HOST"
done
