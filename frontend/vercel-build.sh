#!/bin/bash
set -e

# Ensure Flutter SDK is available in the Vercel Linux build environment
if ! command -v flutter &> /dev/null; then
  echo "Flutter SDK not found. Installing Flutter SDK (stable)..."
  if [ ! -d "$HOME/flutter" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
  fi
  export PATH="$PATH:$HOME/flutter/bin"
fi

echo "Flutter version:"
flutter --version

echo "Configuring Flutter..."
flutter config --no-analytics

echo "Resolving dependencies..."
flutter pub get

echo "Building Flutter Web in release mode..."
flutter build web --release

echo "Verifying and mirroring font assets across paths..."
mkdir -p build/web/assets/fonts
cp -r build/web/assets/assets/fonts/* build/web/assets/fonts/ 2>/dev/null || true
mkdir -p build/web/fonts
cp -r build/web/assets/assets/fonts/* build/web/fonts/ 2>/dev/null || true

echo "Verifying build output:"
if [ -f "build/web/index.html" ] && [ -f "build/web/assets/assets/fonts/SpaceGrotesk-Regular.ttf" ]; then
  echo "SUCCESS: build/web/index.html and Space Grotesk font files exist."
else
  echo "ERROR: build/web/index.html or font files were not generated."
  exit 1
fi
