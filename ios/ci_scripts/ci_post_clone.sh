#!/bin/sh

# Fail if any command fails
set -e

# 1. Navigate to the root of your project
cd $CI_WORKSPACE

# 2. Install Flutter (Xcode Cloud doesn't have it by default)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# 3. Generate the config files (This creates the "Generated.xcconfig" for the Cloud)
flutter pub get

# 4. Install CocoaPods
cd ios
pod install

exit 0