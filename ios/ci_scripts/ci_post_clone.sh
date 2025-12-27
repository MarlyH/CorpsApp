#!/bin/sh

# Fail on error
set -e

# Xcode Cloud executes from the 'ci_scripts' directory.
# Move to the root of the repository (usually 2 levels up from ci_scripts)
cd "$(dirname "$0")/../.."

# Install Flutter via homebrew if it's not detected (Xcode Cloud has Homebrew)
if ! command -v flutter &> /dev/null
then
    echo "Flutter not found, installing via Homebrew..."
    brew install --cask flutter
fi

# Precache and get packages
flutter precache --ios
flutter pub get

# Navigate to the iOS folder and install pods
cd ios
pod install