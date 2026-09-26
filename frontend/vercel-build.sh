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

echo "Verifying build output:"
if [ -f "build/web/index.html" ]; then
  echo "SUCCESS: build/web/index.html exists."
else
  echo "ERROR: build/web/index.html was not generated."
  exit 1
fi
