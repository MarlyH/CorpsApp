#!/bin/sh
set -e

echo "===== CI POST CLONE SCRIPT START ====="

# --------------------------------------------------
# Resolve project root from script location
# Script path: ios/ci_scripts/ci_post_clone.sh
# Project root: two levels up
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Script directory : $SCRIPT_DIR"
echo "Project root     : $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Sanity check
if [ ! -d "ios" ]; then
  echo "ERROR: ios directory not found in project root"
  exit 1
fi

# --------------------------------------------------
# Install Flutter (stable) if not already installed
# --------------------------------------------------
echo "===== SETTING UP FLUTTER ====="

FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
else
  echo "Flutter SDK already exists"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

flutter --version
flutter precache --ios

# --------------------------------------------------
# Create .env file
# --------------------------------------------------
echo "===== CREATING .ENV FILE ====="

: "${API_BASE_URL:?ERROR: API_BASE_URL is not set}"

cat <<EOF > .env
API_BASE_URL=$API_BASE_URL
EOF

echo ".env file created successfully"

# --------------------------------------------------
# Flutter dependencies
# --------------------------------------------------
echo "===== FLUTTER PUB GET ====="
flutter pub get

# --------------------------------------------------
# CocoaPods
# --------------------------------------------------
echo "===== INSTALLING COCOAPODS ====="

if ! brew list cocoapods >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
else
  echo "CocoaPods already installed"
fi

echo "===== INSTALLING IOS PODS ====="
cd ios
pod install

echo "===== CI POST CLONE SCRIPT COMPLETE ====="
exit 0
