#!/bin/sh

# 'set -x' helps you see every command in the logs
set -x
set -e

echo "===== CI POST CLONE SCRIPT START ====="

# 1. Dynamic Path Calculation
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Script directory : $SCRIPT_DIR"
echo "Project root     : $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Safety Check
if [ ! -d "ios" ]; then
  echo "ERROR: ios directory not found at $PROJECT_ROOT/ios"
  exit 1
fi

# 2. Setup Flutter
echo "===== SETTING UP FLUTTER ====="
FLUTTER_DIR="$HOME/flutter"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
fi
export PATH="$PATH:$FLUTTER_DIR/bin"
flutter precache --ios

# 3. Create .env
echo "===== CREATING .ENV FILE ====="
if [ -z "$API_BASE_URL" ]; then
  echo "WARNING: API_BASE_URL is not set!"
fi
cat <<EOF > .env
API_BASE_URL=$API_BASE_URL
EOF

# 4. [NEW] Patch AppFrameworkInfo.plist to fix ITMS-90530
# This forces the MinimumOSVersion to 13.0 (or whatever your app uses)
# so the App.framework is valid for the App Store.
echo "===== PATCHING FLUTTER FRAMEWORK PLIST ====="
PLIST_PATH="ios/Flutter/AppFrameworkInfo.plist"

# Ensure the key exists (Add it if missing) or Set it if present
/usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string 15.6" "$PLIST_PATH" || /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion 15.6" "$PLIST_PATH"

echo "Patched $PLIST_PATH with MinimumOSVersion 15.6"

# 5. Install Dependencies
echo "===== FLUTTER PUB GET ====="
flutter pub get

echo "===== INSTALLING COCOAPODS ====="
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

echo "===== INSTALLING IOS PODS ====="
cd ios

rm -rf Pods
rm -f Podfile.lock

pod install --repo-update

pod update Firebase/Messaging

echo "===== SUCCESS ====="
exit 0