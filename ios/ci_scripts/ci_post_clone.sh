#!/bin/sh

set -e # Exit on error

# Xcode Cloud runs this script from ios/ci_scripts.
# We need to move up TWO levels to get to the Project Root.
cd ../..

# 1. Install Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# 2. Precache (Good practice for CI)
flutter precache --ios

# 3. Get dependencies (This creates the flutter_export_environment.sh you were missing)
flutter pub get

# 4. Install CocoaPods
# Using brew is standard for Xcode Cloud to ensure it's available
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

# 5. Install Pods
cd ios
pod install

exit 0