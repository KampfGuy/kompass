#!/usr/bin/env bash
# Build the Kompass VR APK (Meta Quest).  Usage: vr/build-apk.sh [debug|release]
# Needs: JDK 17, Android SDK (platform 34 + build-tools 34), Gradle 8.7, node.
# Signing: set KOMPASS_VR_KEYSTORE (+ KOMPASS_VR_KEYSTORE_PASS, KOMPASS_VR_KEY_ALIAS) to a keystore OUTSIDE the repo;
# without it Gradle signs with the standard Android debug key (~/.android/debug.keystore).
set -euo pipefail
cd "$(dirname "$0")/.."
TYPE="${1:-debug}"
export JAVA_HOME="${JAVA_HOME:-/opt/jdk/jdk-17.0.21+9}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
GRADLE="${GRADLE:-/opt/gradle/gradle-8.7/bin/gradle}"
echo "sdk.dir=$ANDROID_HOME" > android/local.properties
VER=$(node -p "require('./vr/version.json').versionName")
( cd android && "$GRADLE" --no-daemon -q "assemble${TYPE^}" )
OUT="android/app/build/outputs/apk/$TYPE/app-$TYPE.apk"
DIST="${KOMPASS_VR_DIST:-/workspace/kompass-vr-dist}"
mkdir -p "$DIST"
cp "$OUT" "$DIST/Kompass-VR-$VER.apk"
echo "APK: $DIST/Kompass-VR-$VER.apk"
