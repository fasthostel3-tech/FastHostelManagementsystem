#!/bin/bash
set -e

echo "=== Starting Flutter Web Build ==="
echo "Current directory: $(pwd)"

# Install Flutter SDK if not already present
if [ ! -d "flutter_sdk" ]; then
  echo "=== Cloning Flutter stable ==="
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter_sdk
else
  echo "=== Flutter SDK already exists ==="
fi

export PATH="$PATH:$(pwd)/flutter_sdk/bin"

echo "=== Flutter version ==="
flutter --version --suppress-analytics

echo "=== Enabling web support ==="
flutter config --enable-web --suppress-analytics

echo "=== Running pub get ==="
flutter pub get --suppress-analytics

echo "=== Building web ==="
flutter build web --release --no-tree-shake-icons --suppress-analytics

echo "=== Build complete! ==="
ls -la build/web/
