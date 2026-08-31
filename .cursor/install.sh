#!/usr/bin/env bash
# Idempotent Cloud Agent setup for No Time Media (Flutter app + Supabase edge functions).
#
# Installs, if missing:
#   - Flutter 3.29.3 (bundles Dart 3.7.2 — matches pubspec `sdk: ^3.7.2` and the
#     project's committed Android Gradle config: AGP 8.7.0 / Gradle 8.10.2)
#   - Deno (for the Supabase Edge Functions under supabase/functions)
#   - Android command-line tools, platform-tools, platform 36, build-tools 36,
#     NDK 27.0.12077973 (compileSdk/ndkVersion from android/app/build.gradle.kts),
#     plus the emulator + an x86_64 system image for local runs
# Then refreshes Dart dependencies and regenerates freezed/json/hive code.
#
# Safe to re-run: every step is guarded and skips work that is already done.
set -euo pipefail

FLUTTER_VERSION="3.29.3"
FLUTTER_HOME="/opt/flutter"
DENO_HOME="/opt/deno"
ANDROID_SDK_ROOT="/opt/android-sdk"
CMDLINE_TOOLS_VERSION="11076708"
ANDROID_PLATFORM="platforms;android-36"
ANDROID_BUILD_TOOLS="build-tools;36.0.0"
ANDROID_NDK="ndk;27.0.12077973"
ANDROID_SYSTEM_IMAGE="system-images;android-35;google_apis;x86_64"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/no_time_media"

# Use sudo only when required and available.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
fi

log() { printf '\n=== %s ===\n' "$1"; }

log "System packages"
if command -v apt-get >/dev/null 2>&1; then
  $SUDO apt-get update -y || true
  # curl/unzip/xz for downloads; mesa/GL libs for the Flutter tooling and emulator.
  $SUDO apt-get install -y --no-install-recommends \
    curl unzip xz-utils git ca-certificates \
    libglu1-mesa libpulse0 || true
fi

log "Flutter $FLUTTER_VERSION"
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  $SUDO rm -rf "$FLUTTER_HOME"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  $SUDO mkdir -p "$(dirname "$FLUTTER_HOME")"
  $SUDO tar -xf "$tmp/flutter.tar.xz" -C "$(dirname "$FLUTTER_HOME")"
  $SUDO chown -R "$(id -u):$(id -g)" "$FLUTTER_HOME"
  rm -rf "$tmp"
fi
git config --global --add safe.directory "$FLUTTER_HOME" || true
export PATH="$FLUTTER_HOME/bin:$PATH"
flutter config --no-analytics >/dev/null 2>&1 || true

log "Deno"
if [ ! -x "$DENO_HOME/bin/deno" ]; then
  $SUDO mkdir -p "$DENO_HOME"
  $SUDO chown -R "$(id -u):$(id -g)" "$DENO_HOME"
  curl -fsSL https://deno.land/install.sh | DENO_INSTALL="$DENO_HOME" sh -s -- -y
fi
export PATH="$DENO_HOME/bin:$PATH"

log "Android SDK"
export ANDROID_SDK_ROOT ANDROID_HOME="$ANDROID_SDK_ROOT"
if [ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  $SUDO mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  $SUDO chown -R "$(id -u):$(id -g)" "$ANDROID_SDK_ROOT"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/cmdtools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  unzip -q "$tmp/cmdtools.zip" -d "$ANDROID_SDK_ROOT/cmdline-tools"
  mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -rf "$tmp"
fi
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
yes | sdkmanager --licenses >/dev/null 2>&1 || true
sdkmanager "platform-tools" "$ANDROID_PLATFORM" "$ANDROID_BUILD_TOOLS" "$ANDROID_NDK" \
  "emulator" "$ANDROID_SYSTEM_IMAGE" >/dev/null 2>&1 || true
flutter config --android-sdk "$ANDROID_SDK_ROOT" >/dev/null 2>&1 || true
yes | flutter doctor --android-licenses >/dev/null 2>&1 || true

log "Persist toolchain PATH for interactive shells"
BASHRC="$HOME/.bashrc"
LINE='export PATH="/opt/flutter/bin:/opt/deno/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:$PATH"'
if ! grep -qF "/opt/flutter/bin" "$BASHRC" 2>/dev/null; then
  {
    echo "$LINE"
    echo 'export ANDROID_SDK_ROOT="/opt/android-sdk"'
    echo 'export ANDROID_HOME="/opt/android-sdk"'
  } >> "$BASHRC"
fi

log "Flutter dependencies + code generation"
cd "$APP_DIR"
flutter pub get
dart run build_runner build --delete-conflicting-outputs

log "Cache Deno edge-function dependencies"
cd "$REPO_ROOT/supabase/functions"
deno check generate-post/index.ts || true

log "Setup complete"
flutter --version
deno --version | head -1
