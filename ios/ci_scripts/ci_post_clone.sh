#!/bin/sh

set -e # Exit on error

cd ../..

# Install Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Precache
flutter precache --ios

# Move to the project root
cd "$CI_WORKSPACE"

echo "--- RECREATING .ENV FILE ---"
cat <<EOF > .env
API_BASE_URL=$API_BASE_URL
EOF

echo ".env file created successfully."

# Get dependencies
flutter pub get

# Install CocoaPods
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

# Install Pods
cd ios
pod install

exit 0